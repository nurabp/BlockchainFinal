// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { GovernanceToken } from "../src/token/GovernanceToken.sol";
import { AssetBadgeNFT } from "../src/token/AssetBadgeNFT.sol";
import { RwaVault } from "../src/vault/RwaVault.sol";
import { ConstantProductAMM } from "../src/amm/ConstantProductAMM.sol";
import { MockV3Aggregator } from "../src/mocks/MockV3Aggregator.sol";
import { ChainlinkOracleAdapter } from "../src/oracle/ChainlinkOracleAdapter.sol";
import { SimpleTimelock } from "../src/governance/SimpleTimelock.sol";
import { ProtocolGovernor } from "../src/governance/ProtocolGovernor.sol";
import { ProtocolFactory } from "../src/factory/ProtocolFactory.sol";
import { RwaIssuerUpgradeable } from "../src/upgrade/RwaIssuerUpgradeable.sol";
import { RwaIssuerV2 } from "../src/upgrade/RwaIssuerV2.sol";
import { ERC1967ProxyLite } from "../src/upgrade/ERC1967ProxyLite.sol";
import { VulnerableBank, FixedBank } from "./VulnerabilityCases.sol";
import { YulMath } from "../src/utils/YulMath.sol";

interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
}

contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "ASSERT_EQ_UINT");
    }

    function assertEq(address a, address b) internal pure {
        require(a == b, "ASSERT_EQ_ADDRESS");
    }

    function assertTrue(bool value) internal pure {
        require(value, "ASSERT_TRUE");
    }
}

contract ProtocolTest is TestBase {
    GovernanceToken token;
    GovernanceToken usd;
    AssetBadgeNFT badge;
    RwaVault vault;
    ConstantProductAMM amm;
    MockV3Aggregator feed;
    ChainlinkOracleAdapter oracle;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        token = new GovernanceToken(address(this));
        usd = new GovernanceToken(address(this));
        badge = new AssetBadgeNFT(address(this));
        vault = new RwaVault(token, address(this));
        amm = new ConstantProductAMM(token, usd);
        feed = new MockV3Aggregator(8, 1000e8);
        oracle = new ChainlinkOracleAdapter(address(feed), 1 days);
        token.mint(address(this), 2_000_000 ether);
        usd.mint(address(this), 2_000_000 ether);
        token.mint(alice, 100_000 ether);
        usd.mint(alice, 100_000 ether);
    }

    function testMintAndTransfer() public {
        token.transfer(bob, 1 ether);
        assertEq(token.balanceOf(bob), 1 ether);
    }

    function testIssuerRoleCanIssueBackedTokens() public {
        token.issueBackedTokens(bob, 2 ether, "ipfs://proof");
        assertEq(token.balanceOf(bob), 2 ether);
    }

    function testDelegateVotingPower() public {
        token.delegate(address(this));
        assertEq(token.votingPower(address(this)), token.balanceOf(address(this)));
    }

    function testVotingPowerMovesOnTransfer() public {
        token.delegate(address(this));
        uint256 beforeVotes = token.votingPower(address(this));
        token.transfer(bob, 100 ether);
        assertEq(token.votingPower(address(this)), beforeVotes - 100 ether);
    }

    function testBadgeMint() public {
        uint256 id = badge.mint(alice, "ipfs://asset-1");
        assertEq(badge.ownerOf(id), alice);
        assertEq(badge.balanceOf(alice), 1);
    }

    function testVaultDepositMintsShares() public {
        token.approve(address(vault), 100 ether);
        uint256 shares = vault.deposit(100 ether, address(this));
        assertEq(shares, 100 ether);
        assertEq(vault.balanceOf(address(this)), 100 ether);
    }

    function testVaultWithdrawBurnsShares() public {
        token.approve(address(vault), 100 ether);
        vault.deposit(100 ether, address(this));
        vault.withdraw(40 ether, address(this), address(this));
        assertEq(vault.balanceOf(address(this)), 60 ether);
    }

    function testVaultRejectsZeroDeposit() public {
        token.approve(address(vault), 1);
        vm.expectRevert(bytes("ZERO_ASSETS"));
        vault.deposit(0, address(this));
    }

    function testAmmInitialLiquidity() public {
        token.approve(address(amm), 100 ether);
        usd.approve(address(amm), 100 ether);
        uint256 lp = amm.addLiquidity(100 ether, 100 ether, 1);
        assertEq(lp, 100 ether);
        assertEq(amm.reserve0(), 100 ether);
    }

    function testAmmSwapKeepsK() public {
        token.approve(address(amm), 1000 ether);
        usd.approve(address(amm), 1000 ether);
        amm.addLiquidity(500 ether, 500 ether, 1);
        uint256 kBefore = uint256(amm.reserve0()) * uint256(amm.reserve1());
        amm.swap(address(token), 10 ether, 1);
        uint256 kAfter = uint256(amm.reserve0()) * uint256(amm.reserve1());
        assertTrue(kAfter >= kBefore);
    }

    function testAmmRemoveLiquidity() public {
        token.approve(address(amm), 100 ether);
        usd.approve(address(amm), 100 ether);
        uint256 lp = amm.addLiquidity(100 ether, 100 ether, 1);
        amm.removeLiquidity(lp / 2, 1, 1);
        assertEq(amm.balanceOf(address(this)), lp / 2);
    }

    function testOraclePrice() public {
        (uint256 price, uint8 decimals) = oracle.latestPrice();
        assertEq(price, 1000e8);
        assertEq(decimals, 8);
    }

    function testOracleRejectsBadPrice() public {
        feed.updateAnswer(0);
        vm.expectRevert(abi.encodeWithSelector(ChainlinkOracleAdapter.BadPrice.selector));
        oracle.latestPrice();
    }

    function testOracleRejectsStalePrice() public {
        feed.setUpdatedAt(1);
        vm.warp(3 days);
        vm.expectRevert();
        oracle.latestPrice();
    }

    function testFactoryCreateAmm() public {
        ProtocolFactory factory = new ProtocolFactory();
        address pair = factory.createAMM(token, usd);
        assertTrue(pair.code.length > 0);
    }

    function testFactoryCreate2ProxyPrediction() public {
        ProtocolFactory factory = new ProtocolFactory();
        RwaIssuerUpgradeable impl = new RwaIssuerUpgradeable();
        bytes memory init =
            abi.encodeCall(RwaIssuerUpgradeable.initialize, (address(token), address(this)));
        bytes32 salt = keccak256("issuer");
        address predicted = factory.predictProxyAddress(address(impl), init, salt);
        address proxy = factory.createUUPSProxy(address(impl), init, salt);
        assertEq(predicted, proxy);
    }

    function testUUPSUpgradePath() public {
        RwaIssuerUpgradeable impl = new RwaIssuerUpgradeable();
        bytes memory init =
            abi.encodeCall(RwaIssuerUpgradeable.initialize, (address(token), address(this)));
        ERC1967ProxyLite proxy = new ERC1967ProxyLite(address(impl), init);
        RwaIssuerUpgradeable issuer = RwaIssuerUpgradeable(address(proxy));
        RwaIssuerV2 impl2 = new RwaIssuerV2();
        issuer.upgradeTo(address(impl2));
        RwaIssuerV2(address(proxy)).setVersion2();
        assertEq(issuer.version(), 2);
    }

    function testYulMinMatchesSolidityMin() public pure {
        require(YulMath.minYul(7, 4) == YulMath.minSolidity(7, 4), "MIN_MISMATCH");
        require(YulMath.minYul(2, 8) == YulMath.minSolidity(2, 8), "MIN_MISMATCH");
    }

    function testGovernanceLifecycleToSucceeded() public {
        token.delegate(address(this));
        SimpleTimelock timelock = new SimpleTimelock(2 days, address(this));
        ProtocolGovernor governor = new ProtocolGovernor(token, timelock);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        bytes memory data = abi.encodeCall(GovernanceToken.mint, (bob, 1 ether));
        uint256 id = governor.propose(address(token), 0, data, "Mint treasury incentive");
        vm.warp(block.timestamp + 1 days + 1);
        governor.castVote(id, true);
        vm.warp(block.timestamp + 8 days);
        assertEq(uint256(governor.state(id)), uint256(ProtocolGovernor.ProposalState.Succeeded));
    }

    function testFixedBankAccessControl() public {
        FixedBank bank = new FixedBank();
        vm.prank(alice);
        vm.expectRevert(bytes("NOT_OWNER"));
        bank.sweep(payable(alice));
    }

    function testVulnerableAndFixedBanksExistForAuditCaseStudy() public {
        VulnerableBank vulnerable = new VulnerableBank();
        FixedBank fixedBank = new FixedBank();
        assertTrue(address(vulnerable).code.length > 0);
        assertTrue(address(fixedBank).code.length > 0);
    }

    function testFuzzVaultRoundTrip(uint96 amount) public {
        uint256 assets = uint256(amount % 100_000 ether) + 1;
        token.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, address(this));
        uint256 back = vault.convertToAssets(shares);
        assertEq(back, assets);
    }

    function testFuzzAmmQuoteDoesNotReturnZero(uint96 amount) public {
        uint256 amountIn = uint256(amount % 100 ether) + 1 ether;
        token.approve(address(amm), 1000 ether + amountIn);
        usd.approve(address(amm), 1000 ether);
        amm.addLiquidity(1000 ether, 1000 ether, 1);
        uint256 beforeOut = usd.balanceOf(address(this));
        amm.swap(address(token), amountIn, 1);
        assertTrue(usd.balanceOf(address(this)) > beforeOut);
    }
}

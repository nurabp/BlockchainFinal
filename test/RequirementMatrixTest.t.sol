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
import { YulMath } from "../src/utils/YulMath.sol";

interface MatrixVm {
    function warp(uint256) external;
    function prank(address) external;
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
}

contract MatrixBase {
    MatrixVm internal constant VM =
        MatrixVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function eq(uint256 a, uint256 b) internal pure {
        require(a == b, "EQ_UINT");
    }

    function eq(address a, address b) internal pure {
        require(a == b, "EQ_ADDRESS");
    }

    function ok(bool value) internal pure {
        require(value, "NOT_OK");
    }
}

contract RequirementMatrixTest is MatrixBase {
    GovernanceToken rwa;
    GovernanceToken usd;
    AssetBadgeNFT badge;
    RwaVault vault;
    ConstantProductAMM amm;
    MockV3Aggregator feed;
    ChainlinkOracleAdapter oracle;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        rwa = new GovernanceToken(address(this));
        usd = new GovernanceToken(address(this));
        badge = new AssetBadgeNFT(address(this));
        vault = new RwaVault(rwa, address(this));
        amm = new ConstantProductAMM(rwa, usd);
        feed = new MockV3Aggregator(8, 1200e8);
        oracle = new ChainlinkOracleAdapter(address(feed), 1 days);
        rwa.mint(address(this), 1_000_000 ether);
        usd.mint(address(this), 1_000_000 ether);
        rwa.mint(alice, 10_000 ether);
        usd.mint(alice, 10_000 ether);
    }

    function test001TokenName() public view {
        ok(keccak256(bytes(rwa.name())) == keccak256("RWA Governance Token"));
    }

    function test002TokenSymbol() public view {
        ok(keccak256(bytes(rwa.symbol())) == keccak256("RWAG"));
    }

    function test003TokenDecimals() public view {
        eq(rwa.decimals(), 18);
    }

    function test004InitialSupply() public view {
        eq(rwa.totalSupply(), 1_010_000 ether);
    }

    function test005AdminHasMinterRole() public view {
        ok(rwa.hasRole(rwa.MINTER_ROLE(), address(this)));
    }

    function test006AdminHasIssuerRole() public view {
        ok(rwa.hasRole(rwa.ISSUER_ROLE(), address(this)));
    }

    function test007ApproveStoresAllowance() public {
        rwa.approve(alice, 7 ether);
        eq(rwa.allowance(address(this), alice), 7 ether);
    }

    function test008TransferFromUsesAllowance() public {
        rwa.approve(alice, 8 ether);
        VM.prank(alice);
        rwa.transferFrom(address(this), bob, 8 ether);
        eq(rwa.balanceOf(bob), 8 ether);
    }

    function test009TransferToZeroReverts() public {
        VM.expectRevert(bytes("ZERO_TO"));
        rwa.transfer(address(0), 1);
    }

    function test010TransferOverBalanceReverts() public {
        VM.prank(bob);
        VM.expectRevert(bytes("BALANCE"));
        rwa.transfer(alice, 1);
    }

    function test011NonMinterCannotMint() public {
        VM.prank(alice);
        VM.expectRevert(bytes("MISSING_ROLE"));
        rwa.mint(alice, 1);
    }

    function test012GrantAndRevokeRole() public {
        rwa.grantRole(rwa.MINTER_ROLE(), alice);
        ok(rwa.hasRole(rwa.MINTER_ROLE(), alice));
        rwa.revokeRole(rwa.MINTER_ROLE(), alice);
        ok(!rwa.hasRole(rwa.MINTER_ROLE(), alice));
    }

    function test013DelegateToSelf() public {
        rwa.delegate(address(this));
        eq(rwa.votingPower(address(this)), rwa.balanceOf(address(this)));
    }

    function test014DelegateToAlice() public {
        rwa.delegate(alice);
        eq(rwa.votingPower(alice), rwa.balanceOf(address(this)));
    }

    function test015DelegateMoveAfterTransfer() public {
        rwa.delegate(alice);
        uint256 beforeVotes = rwa.votingPower(alice);
        rwa.transfer(bob, 3 ether);
        eq(rwa.votingPower(alice), beforeVotes - 3 ether);
    }

    function test016NonceStartsZero() public view {
        eq(rwa.nonces(address(this)), 0);
    }

    function test017PermitRejectsBadSignature() public {
        VM.expectRevert(bytes("BAD_SIGNATURE"));
        rwa.permit(address(this), alice, 1, block.timestamp + 1, 27, bytes32(0), bytes32(0));
    }

    function test018PermitRejectsExpired() public {
        VM.expectRevert(bytes("PERMIT_EXPIRED"));
        rwa.permit(address(this), alice, 1, block.timestamp - 1, 27, bytes32(0), bytes32(0));
    }

    function test019IssueBackedTokenEmitsBalanceChange() public {
        rwa.issueBackedTokens(alice, 5 ether, "proof");
        eq(rwa.balanceOf(alice), 10_005 ether);
    }

    function test020BadgeName() public view {
        ok(keccak256(bytes(badge.name())) == keccak256("RWA Asset Badge"));
    }

    function test021BadgeMintIncrementsSupply() public {
        badge.mint(alice, "uri");
        eq(badge.totalSupply(), 1);
    }

    function test022BadgeTokenUriStored() public {
        uint256 id = badge.mint(alice, "ipfs://x");
        ok(keccak256(bytes(badge.tokenURI(id))) == keccak256("ipfs://x"));
    }

    function test023BadgeApproveAndTransfer() public {
        uint256 id = badge.mint(address(this), "uri");
        badge.approve(alice, id);
        VM.prank(alice);
        badge.transferFrom(address(this), bob, id);
        eq(badge.ownerOf(id), bob);
    }

    function test024BadgeApprovalForAll() public {
        uint256 id = badge.mint(address(this), "uri");
        badge.setApprovalForAll(alice, true);
        VM.prank(alice);
        badge.transferFrom(address(this), bob, id);
        eq(badge.balanceOf(bob), 1);
    }

    function test025NonMinterCannotBadgeMint() public {
        VM.prank(alice);
        VM.expectRevert(bytes("MISSING_ROLE"));
        badge.mint(alice, "uri");
    }

    function test026VaultAssetAddress() public view {
        eq(address(vault.asset()), address(rwa));
    }

    function test027VaultConvertNoSupply() public view {
        eq(vault.convertToShares(9 ether), 9 ether);
    }

    function test028VaultTotalAssetsStartsZero() public view {
        eq(vault.totalAssets(), 0);
    }

    function test029VaultDepositToAlice() public {
        rwa.approve(address(vault), 9 ether);
        vault.deposit(9 ether, alice);
        eq(vault.balanceOf(alice), 9 ether);
    }

    function test030VaultWithdrawAllowancePath() public {
        rwa.approve(address(vault), 10 ether);
        vault.deposit(10 ether, alice);
        VM.prank(alice);
        vault.approve(address(this), 4 ether);
        vault.withdraw(4 ether, bob, alice);
        eq(rwa.balanceOf(bob), 4 ether);
    }

    function test031VaultWithdrawOverAllowanceReverts() public {
        rwa.approve(address(vault), 10 ether);
        vault.deposit(10 ether, alice);
        VM.expectRevert(bytes("ALLOWANCE"));
        vault.withdraw(4 ether, bob, alice);
    }

    function test032AmmToken0() public view {
        eq(address(amm.token0()), address(rwa));
    }

    function test033AmmToken1() public view {
        eq(address(amm.token1()), address(usd));
    }

    function test034AmmFee() public view {
        eq(amm.FEE_BPS(), 30);
    }

    function test035AmmRejectSameToken() public {
        VM.expectRevert(bytes("SAME_TOKEN"));
        new ConstantProductAMM(rwa, rwa);
    }

    function test036AmmRejectZeroLiquidity() public {
        VM.expectRevert(bytes("ZERO_AMOUNT"));
        amm.addLiquidity(0, 1, 1);
    }

    function test037AmmRejectBadSwapToken() public {
        VM.expectRevert(bytes("BAD_TOKEN"));
        amm.swap(address(0x1234), 1, 1);
    }

    function test038AmmSwapToken1ForToken0() public {
        rwa.approve(address(amm), 100 ether);
        usd.approve(address(amm), 101 ether);
        amm.addLiquidity(100 ether, 100 ether, 1);
        amm.swap(address(usd), 1 ether, 1);
        ok(rwa.balanceOf(address(this)) > 999_900 ether);
    }

    function test039AmmSlippageReverts() public {
        rwa.approve(address(amm), 101 ether);
        usd.approve(address(amm), 100 ether);
        amm.addLiquidity(100 ether, 100 ether, 1);
        VM.expectRevert(bytes("SLIPPAGE"));
        amm.swap(address(rwa), 1 ether, 99 ether);
    }

    function test040OracleDecimals() public view {
        eq(feed.decimals(), 8);
    }

    function test041OracleUpdate() public {
        feed.updateAnswer(1300e8);
        (uint256 price,) = oracle.latestPrice();
        eq(price, 1300e8);
    }

    function test042OracleStalenessWindow() public view {
        eq(oracle.maxStaleness(), 1 days);
    }

    function test043OracleFeedAddress() public view {
        eq(address(oracle.feed()), address(feed));
    }

    function test044TimelockDelay() public {
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        eq(tl.minDelay(), 2 days);
    }

    function test045TimelockScheduleHash() public {
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        bytes32 salt = keccak256("x");
        bytes32 id = tl.schedule(address(rwa), 0, "", salt);
        eq(tl.timestamps(id), block.timestamp + 2 days);
    }

    function test046TimelockRejectEarlyExecute() public {
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        bytes32 salt = keccak256("x");
        tl.schedule(address(rwa), 0, "", salt);
        VM.expectRevert(bytes("NOT_READY"));
        tl.execute(address(rwa), 0, "", salt);
    }

    function test047GovernorConstants() public {
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        ProtocolGovernor g = new ProtocolGovernor(rwa, tl);
        eq(g.VOTING_DELAY(), 1 days);
        eq(g.VOTING_PERIOD(), 7 days);
        eq(g.QUORUM_BPS(), 400);
    }

    function test048GovernorUnknownStateReverts() public {
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        ProtocolGovernor g = new ProtocolGovernor(rwa, tl);
        VM.expectRevert(bytes("UNKNOWN_PROPOSAL"));
        g.state(999);
    }

    function test049GovernorProposalCreated() public {
        rwa.delegate(address(this));
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        ProtocolGovernor g = new ProtocolGovernor(rwa, tl);
        uint256 id = g.propose(address(rwa), 0, "", "desc");
        eq(id, 1);
    }

    function test049aGovernorDefeatedWhenAgainstWins() public {
        rwa.delegate(address(this));
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        ProtocolGovernor g = new ProtocolGovernor(rwa, tl);
        uint256 id = g.propose(address(rwa), 0, "", "desc");
        VM.warp(block.timestamp + 1 days + 1);
        g.castVote(id, false);
        VM.warp(block.timestamp + 8 days);
        eq(uint256(g.state(id)), uint256(ProtocolGovernor.ProposalState.Defeated));
    }

    function test049bGovernorRejectsDoubleVote() public {
        rwa.delegate(address(this));
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        ProtocolGovernor g = new ProtocolGovernor(rwa, tl);
        uint256 id = g.propose(address(rwa), 0, "", "desc");
        VM.warp(block.timestamp + 1 days + 1);
        g.castVote(id, true);
        VM.expectRevert(bytes("ALREADY_VOTED"));
        g.castVote(id, true);
    }

    function test049cGovernorRejectsEarlyVote() public {
        rwa.delegate(address(this));
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        ProtocolGovernor g = new ProtocolGovernor(rwa, tl);
        uint256 id = g.propose(address(rwa), 0, "", "desc");
        VM.expectRevert(bytes("VOTE_CLOSED"));
        g.castVote(id, true);
    }

    function test049dGovernorQueueAndExecute() public {
        rwa.delegate(address(this));
        SimpleTimelock tl = new SimpleTimelock(2 days, address(this));
        ProtocolGovernor g = new ProtocolGovernor(rwa, tl);
        tl.grantRole(tl.PROPOSER_ROLE(), address(g));
        tl.grantRole(tl.EXECUTOR_ROLE(), address(g));
        rwa.grantRole(rwa.MINTER_ROLE(), address(tl));
        bytes memory data = abi.encodeCall(GovernanceToken.mint, (bob, 1 ether));
        uint256 id = g.propose(address(rwa), 0, data, "mint");
        VM.warp(block.timestamp + 1 days + 1);
        g.castVote(id, true);
        VM.warp(block.timestamp + 8 days);
        g.queue(id);
        eq(uint256(g.state(id)), uint256(ProtocolGovernor.ProposalState.Queued));
        VM.warp(block.timestamp + 2 days + 1);
        g.execute(id);
        eq(uint256(g.state(id)), uint256(ProtocolGovernor.ProposalState.Executed));
    }

    function test050FactoryPredictHasCodeAfterDeploy() public {
        ProtocolFactory f = new ProtocolFactory();
        RwaIssuerUpgradeable impl = new RwaIssuerUpgradeable();
        bytes memory init =
            abi.encodeCall(RwaIssuerUpgradeable.initialize, (address(rwa), address(this)));
        address proxy = f.createUUPSProxy(address(impl), init, keccak256("s"));
        ok(proxy.code.length > 0);
    }

    function test051ProxyImplementationGetter() public {
        RwaIssuerUpgradeable impl = new RwaIssuerUpgradeable();
        ERC1967ProxyLite p = new ERC1967ProxyLite(
            address(impl),
            abi.encodeCall(RwaIssuerUpgradeable.initialize, (address(rwa), address(this)))
        );
        eq(p.implementation(), address(impl));
    }

    function test052IssuerInitializeOnlyOnce() public {
        RwaIssuerUpgradeable impl = new RwaIssuerUpgradeable();
        ERC1967ProxyLite p = new ERC1967ProxyLite(
            address(impl),
            abi.encodeCall(RwaIssuerUpgradeable.initialize, (address(rwa), address(this)))
        );
        VM.expectRevert(bytes("INITIALIZED"));
        RwaIssuerUpgradeable(address(p)).initialize(address(rwa), address(this));
    }

    function test053IssuerSetIssuer() public {
        RwaIssuerUpgradeable issuer = new RwaIssuerUpgradeable();
        issuer.initialize(address(rwa), address(this));
        issuer.setIssuer(alice, true);
        ok(issuer.authorizedIssuers(alice));
    }

    function test054IssuerRejectUnauthorizedIssue() public {
        RwaIssuerUpgradeable issuer = new RwaIssuerUpgradeable();
        issuer.initialize(address(rwa), address(this));
        VM.expectRevert(bytes("NOT_ISSUER"));
        issuer.issue(alice, 1, "proof");
    }

    function test054aIssuerAuthorizedIssue() public {
        RwaIssuerUpgradeable issuer = new RwaIssuerUpgradeable();
        issuer.initialize(address(rwa), address(this));
        rwa.grantRole(rwa.ISSUER_ROLE(), address(issuer));
        issuer.setIssuer(alice, true);
        VM.prank(alice);
        issuer.issue(bob, 1 ether, "proof");
        eq(rwa.balanceOf(bob), 1 ether);
    }

    function test054bIssuerV2BatchIssue() public {
        RwaIssuerV2 issuer = new RwaIssuerV2();
        issuer.initialize(address(rwa), address(this));
        rwa.grantRole(rwa.ISSUER_ROLE(), address(issuer));
        issuer.setIssuer(address(this), true);
        address[] memory accounts = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        accounts[0] = alice;
        accounts[1] = bob;
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        issuer.batchIssue(accounts, amounts, "proof");
        eq(rwa.balanceOf(alice), 10_001 ether);
        eq(rwa.balanceOf(bob), 2 ether);
    }

    function test054cIssuerV2BatchRejectsLengthMismatch() public {
        RwaIssuerV2 issuer = new RwaIssuerV2();
        issuer.initialize(address(rwa), address(this));
        address[] memory accounts = new address[](1);
        uint256[] memory amounts = new uint256[](2);
        VM.expectRevert(bytes("LENGTH"));
        issuer.batchIssue(accounts, amounts, "proof");
    }

    function test055YulSqrt() public pure {
        eq(YulMath.sqrt(10_000), 100);
    }

    function test056YulMinEqual() public pure {
        eq(YulMath.minYul(42, 42), 42);
    }

    function test057YulMinLeft() public pure {
        eq(YulMath.minYul(5, 9), 5);
    }

    function test058YulMinRight() public pure {
        eq(YulMath.minYul(9, 5), 5);
    }

    function testFuzz059Transfer(uint96 amount) public {
        uint256 value = uint256(amount % 1000 ether);
        rwa.transfer(alice, value);
        eq(rwa.balanceOf(alice), 10_000 ether + value);
    }

    function testFuzz060Approve(uint96 amount) public {
        uint256 value = uint256(amount);
        rwa.approve(alice, value);
        eq(rwa.allowance(address(this), alice), value);
    }

    function testFuzz061VaultConvert(uint96 amount) public view {
        uint256 value = uint256(amount);
        eq(vault.convertToShares(value), value);
    }

    function testFuzz062OraclePositivePrices(uint96 price) public {
        uint256 p = uint256(price % 1_000_000e8) + 1;
        feed.updateAnswer(int256(p));
        (uint256 latest,) = oracle.latestPrice();
        eq(latest, p);
    }

    function testFuzz063YulMin(uint96 a, uint96 b) public pure {
        eq(YulMath.minYul(a, b), a < b ? a : b);
    }

    function testFuzz064SqrtFloor(uint96 a) public pure {
        uint256 x = uint256(a);
        uint256 r = YulMath.sqrt(x);
        ok(r * r <= x);
        ok((r + 1) * (r + 1) > x || r == type(uint128).max);
    }

    function testFuzz065BadgeMintUri(uint96 salt) public {
        string memory uri = salt % 2 == 0 ? "ipfs://even" : "ipfs://odd";
        uint256 id = badge.mint(alice, uri);
        ok(keccak256(bytes(badge.tokenURI(id))) == keccak256(bytes(uri)));
    }

    function testFuzz066AmmAddLiquidity(uint96 amount) public {
        uint256 value = uint256(amount % 1000 ether) + 1 ether;
        rwa.approve(address(amm), value);
        usd.approve(address(amm), value);
        uint256 lp = amm.addLiquidity(value, value, 1);
        eq(lp, value);
    }

    function invariant067TokenSupplyAtLeastBalances() public view {
        ok(rwa.totalSupply() >= rwa.balanceOf(address(this)));
    }

    function invariant068VaultAssetsEqualTokenBalance() public view {
        eq(vault.totalAssets(), rwa.balanceOf(address(vault)));
    }

    function invariant069AmmReservesEqualBalances() public view {
        eq(amm.reserve0(), rwa.balanceOf(address(amm)));
        eq(amm.reserve1(), usd.balanceOf(address(amm)));
    }

    function invariant070OracleFeedConfigured() public view {
        ok(address(oracle.feed()) != address(0));
    }

    function invariant071NoZeroAdminRoleForThis() public view {
        ok(rwa.hasRole(rwa.DEFAULT_ADMIN_ROLE(), address(this)));
    }
}

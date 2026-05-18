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
import { ERC1967ProxyLite } from "../src/upgrade/ERC1967ProxyLite.sol";

interface Vm {
    function envUint(string calldata name) external returns (uint256 value);
    function addr(uint256 privateKey) external returns (address keyAddr);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract Deploy {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant SEED_RWA = 1_000_000 ether;
    uint256 private constant SEED_USD = 1_000_000 ether;
    uint256 private constant VAULT_SEED = 50_000 ether;
    uint256 private constant AMM_SEED_RWA = 100_000 ether;
    uint256 private constant AMM_SEED_USD = 100_000 ether;

    struct Deployment {
        GovernanceToken rwa;
        GovernanceToken usd;
        AssetBadgeNFT badge;
        RwaVault vault;
        ConstantProductAMM amm;
        MockV3Aggregator feed;
        ChainlinkOracleAdapter oracle;
        SimpleTimelock timelock;
        ProtocolGovernor governor;
        ProtocolFactory factory;
        RwaIssuerUpgradeable issuerImplementation;
        ERC1967ProxyLite issuerProxy;
        RwaIssuerUpgradeable issuer;
    }

    event CoreDeployed(
        address indexed rwa,
        address indexed usd,
        address indexed badge,
        address vault,
        address amm,
        address oracle
    );
    event GovernanceDeployed(address indexed timelock, address indexed governor, address factory);
    event IssuerDeployed(address indexed implementation, address indexed proxy);
    event Seeded(address indexed deployer, uint256 rwaMinted, uint256 usdMinted);

    function run() external returns (Deployment memory d) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);
        d = _deploy(deployer);
        _seedAndHarden(d, deployer);
        vm.stopBroadcast();
    }

    function deploy(address admin) external returns (Deployment memory d) {
        d = _deploy(admin);
    }

    function _deploy(address admin) internal returns (Deployment memory d) {
        d.rwa = new GovernanceToken(admin);
        d.usd = new GovernanceToken(admin);
        d.badge = new AssetBadgeNFT(admin);
        d.feed = new MockV3Aggregator(8, 1000e8);
        d.oracle = new ChainlinkOracleAdapter(address(d.feed), 1 days);
        d.timelock = new SimpleTimelock(2 days, admin);
        d.vault = new RwaVault(d.rwa, address(d.timelock));
        d.amm = new ConstantProductAMM(d.rwa, d.usd);
        d.governor = new ProtocolGovernor(d.rwa, d.timelock);
        d.factory = new ProtocolFactory();

        d.issuerImplementation = new RwaIssuerUpgradeable();
        bytes memory init = abi.encodeCall(RwaIssuerUpgradeable.initialize, (address(d.rwa), admin));
        d.issuerProxy = new ERC1967ProxyLite(address(d.issuerImplementation), init);
        d.issuer = RwaIssuerUpgradeable(address(d.issuerProxy));

        emit CoreDeployed(
            address(d.rwa),
            address(d.usd),
            address(d.badge),
            address(d.vault),
            address(d.amm),
            address(d.oracle)
        );
        emit GovernanceDeployed(address(d.timelock), address(d.governor), address(d.factory));
        emit IssuerDeployed(address(d.issuerImplementation), address(d.issuerProxy));
    }

    function _seedAndHarden(Deployment memory d, address deployer) internal {
        d.rwa.mint(deployer, SEED_RWA);
        d.usd.mint(deployer, SEED_USD);
        d.rwa.delegate(deployer);

        d.rwa.approve(address(d.vault), VAULT_SEED);
        d.vault.deposit(VAULT_SEED, deployer);

        d.rwa.approve(address(d.amm), AMM_SEED_RWA);
        d.usd.approve(address(d.amm), AMM_SEED_USD);
        d.amm.addLiquidity(AMM_SEED_RWA, AMM_SEED_USD, 1);

        d.badge.mint(deployer, "ipfs://rwa-asset-badge");
        d.rwa.grantRole(d.rwa.ISSUER_ROLE(), address(d.issuer));

        _transferTokenControl(d.rwa, d.timelock, deployer);
        _transferTokenControl(d.usd, d.timelock, deployer);
        d.badge.grantRole(d.badge.DEFAULT_ADMIN_ROLE(), address(d.timelock));
        d.badge.grantRole(d.badge.MINTER_ROLE(), address(d.timelock));
        d.badge.revokeRole(d.badge.MINTER_ROLE(), deployer);
        d.badge.revokeRole(d.badge.DEFAULT_ADMIN_ROLE(), deployer);

        d.timelock.grantRole(d.timelock.DEFAULT_ADMIN_ROLE(), address(d.timelock));
        d.timelock.grantRole(d.timelock.PROPOSER_ROLE(), address(d.governor));
        d.timelock.grantRole(d.timelock.EXECUTOR_ROLE(), address(d.governor));
        d.timelock.revokeRole(d.timelock.PROPOSER_ROLE(), deployer);
        d.timelock.revokeRole(d.timelock.EXECUTOR_ROLE(), deployer);
        d.timelock.revokeRole(d.timelock.DEFAULT_ADMIN_ROLE(), deployer);

        d.issuer.transferAdmin(address(d.timelock));
        emit Seeded(deployer, SEED_RWA, SEED_USD);
    }

    function _transferTokenControl(GovernanceToken token, SimpleTimelock timelock, address deployer)
        internal
    {
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), address(timelock));
        token.grantRole(token.MINTER_ROLE(), address(timelock));
        token.grantRole(token.ISSUER_ROLE(), address(timelock));
        token.revokeRole(token.MINTER_ROLE(), deployer);
        token.revokeRole(token.ISSUER_ROLE(), deployer);
        token.revokeRole(token.DEFAULT_ADMIN_ROLE(), deployer);
    }
}

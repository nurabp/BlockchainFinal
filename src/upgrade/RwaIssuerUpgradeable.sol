// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { GovernanceToken } from "../token/GovernanceToken.sol";

contract RwaIssuerUpgradeable {
    bytes32 public constant IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    GovernanceToken public token;
    address public admin;
    uint256 public version;
    mapping(address => bool) public authorizedIssuers;
    uint256[45] private __gap;

    event Initialized(address token, address admin);
    event IssuerSet(address indexed issuer, bool authorized);
    event Upgraded(address indexed implementation);

    modifier onlyAdmin() {
        require(msg.sender == admin, "NOT_ADMIN");
        _;
    }

    function initialize(address token_, address admin_) external {
        require(admin == address(0), "INITIALIZED");
        token = GovernanceToken(token_);
        admin = admin_;
        version = 1;
        emit Initialized(token_, admin_);
    }

    function setIssuer(address issuer, bool authorized) external onlyAdmin {
        authorizedIssuers[issuer] = authorized;
        emit IssuerSet(issuer, authorized);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "ZERO_ADMIN");
        admin = newAdmin;
    }

    function issue(address to, uint256 amount, string calldata proofUri) external {
        require(authorizedIssuers[msg.sender], "NOT_ISSUER");
        token.issueBackedTokens(to, amount, proofUri);
    }

    function upgradeTo(address newImplementation) external onlyAdmin {
        require(newImplementation.code.length > 0, "NO_CODE");
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
        emit Upgraded(newImplementation);
    }

    function proxiableUUID() external pure returns (bytes32) {
        return IMPLEMENTATION_SLOT;
    }
}

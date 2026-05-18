// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20Base } from "./ERC20Base.sol";
import { AccessControlLite } from "../access/AccessControlLite.sol";

contract GovernanceToken is ERC20Base, AccessControlLite {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    mapping(address => address) public delegates;
    mapping(address => uint256) public nonces;
    mapping(address => uint256) public votingPower;
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    event DelegateChanged(
        address indexed delegator, address indexed fromDelegate, address indexed toDelegate
    );
    event DelegateVotesChanged(
        address indexed delegate, uint256 previousBalance, uint256 newBalance
    );
    event CollateralIssued(
        address indexed issuer, address indexed account, uint256 amount, string proofUri
    );

    constructor(address admin) ERC20Base("RWA Governance Token", "RWAG", 18) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function issueBackedTokens(address to, uint256 amount, string calldata proofUri)
        external
        onlyRole(ISSUER_ROLE)
    {
        _mint(to, amount);
        emit CollateralIssued(msg.sender, to, amount, proofUri);
    }

    function delegate(address delegatee) external {
        _delegate(msg.sender, delegatee);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "PERMIT_EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline)
                )
            )
        );
        require(ecrecover(digest, v, r, s) == owner, "BAD_SIGNATURE");
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function getVotes(address account) external view returns (uint256) {
        return votingPower[account];
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        super._transfer(from, to, amount);
        _moveVotes(delegates[from], delegates[to], amount);
    }

    function _mint(address to, uint256 amount) internal override {
        super._mint(to, amount);
        _moveVotes(address(0), delegates[to], amount);
    }

    function _burn(address from, uint256 amount) internal override {
        super._burn(from, amount);
        _moveVotes(delegates[from], address(0), amount);
    }

    function _delegate(address delegator, address delegatee) internal {
        address current = delegates[delegator];
        delegates[delegator] = delegatee;
        emit DelegateChanged(delegator, current, delegatee);
        _moveVotes(current, delegatee, balanceOf[delegator]);
    }

    function _moveVotes(address from, address to, uint256 amount) internal {
        if (from == to || amount == 0) return;
        if (from != address(0)) {
            uint256 oldVotes = votingPower[from];
            votingPower[from] = oldVotes - amount;
            emit DelegateVotesChanged(from, oldVotes, votingPower[from]);
        }
        if (to != address(0)) {
            uint256 oldVotes = votingPower[to];
            votingPower[to] = oldVotes + amount;
            emit DelegateVotesChanged(to, oldVotes, votingPower[to]);
        }
    }
}


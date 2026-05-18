// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControlLite } from "../access/AccessControlLite.sol";

contract SimpleTimelock is AccessControlLite {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    uint256 public immutable minDelay;
    mapping(bytes32 => uint256) public timestamps;

    event CallScheduled(
        bytes32 indexed id, address indexed target, uint256 value, bytes data, uint256 eta
    );
    event CallExecuted(bytes32 indexed id, address indexed target, uint256 value, bytes data);

    constructor(uint256 minDelay_, address admin) {
        minDelay = minDelay_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PROPOSER_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);
    }

    receive() external payable { }

    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 salt)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(target, value, data, salt));
    }

    function schedule(address target, uint256 value, bytes calldata data, bytes32 salt)
        external
        onlyRole(PROPOSER_ROLE)
        returns (bytes32 id)
    {
        id = hashOperation(target, value, data, salt);
        require(timestamps[id] == 0, "ALREADY_SCHEDULED");
        timestamps[id] = block.timestamp + minDelay;
        emit CallScheduled(id, target, value, data, timestamps[id]);
    }

    function execute(address target, uint256 value, bytes calldata data, bytes32 salt)
        external
        payable
        onlyRole(EXECUTOR_ROLE)
        returns (bytes memory result)
    {
        bytes32 id = hashOperation(target, value, data, salt);
        require(timestamps[id] != 0 && block.timestamp >= timestamps[id], "NOT_READY");
        delete timestamps[id];
        (bool ok, bytes memory ret) = target.call{ value: value }(data);
        require(ok, "CALL_FAILED");
        emit CallExecuted(id, target, value, data);
        return ret;
    }
}


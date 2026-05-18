// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "../interfaces/IERC20.sol";
import { ConstantProductAMM } from "../amm/ConstantProductAMM.sol";
import { ERC1967ProxyLite } from "../upgrade/ERC1967ProxyLite.sol";

contract ProtocolFactory {
    event AMMCreated(address indexed amm, address indexed token0, address indexed token1);
    event ProxyCreated(address indexed proxy, address indexed implementation, bytes32 salt);

    function createAMM(IERC20 token0, IERC20 token1) external returns (address amm) {
        amm = address(new ConstantProductAMM(token0, token1));
        emit AMMCreated(amm, address(token0), address(token1));
    }

    function createUUPSProxy(address implementation, bytes calldata initData, bytes32 salt)
        external
        returns (address proxy)
    {
        proxy = address(new ERC1967ProxyLite{ salt: salt }(implementation, initData));
        emit ProxyCreated(proxy, implementation, salt);
    }

    function predictProxyAddress(address implementation, bytes calldata initData, bytes32 salt)
        external
        view
        returns (address predicted)
    {
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(
                type(ERC1967ProxyLite).creationCode, abi.encode(implementation, initData)
            )
        );
        predicted = address(
            uint160(
                uint256(
                    keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash))
                )
            )
        );
    }
}


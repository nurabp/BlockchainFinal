// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { RwaIssuerUpgradeable } from "./RwaIssuerUpgradeable.sol";

contract RwaIssuerV2 is RwaIssuerUpgradeable {
    event BatchIssued(uint256 count);

    function setVersion2() external onlyAdmin {
        version = 2;
    }

    function batchIssue(
        address[] calldata accounts,
        uint256[] calldata amounts,
        string calldata proofUri
    ) external {
        require(accounts.length == amounts.length, "LENGTH");
        require(authorizedIssuers[msg.sender], "NOT_ISSUER");
        for (uint256 i; i < accounts.length; i++) {
            token.issueBackedTokens(accounts[i], amounts[i], proofUri);
        }
        emit BatchIssued(accounts.length);
    }
}


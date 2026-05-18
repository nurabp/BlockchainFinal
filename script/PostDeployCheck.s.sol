// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { GovernanceToken } from "../src/token/GovernanceToken.sol";
import { SimpleTimelock } from "../src/governance/SimpleTimelock.sol";
import { ProtocolGovernor } from "../src/governance/ProtocolGovernor.sol";

contract PostDeployCheck {
    function check(GovernanceToken token, SimpleTimelock timelock, ProtocolGovernor governor)
        external
        view
        returns (bool)
    {
        require(timelock.minDelay() == 2 days, "BAD_DELAY");
        require(governor.VOTING_DELAY() == 1 days, "BAD_VOTING_DELAY");
        require(governor.VOTING_PERIOD() == 7 days, "BAD_VOTING_PERIOD");
        require(governor.QUORUM_BPS() == 400, "BAD_QUORUM");
        require(address(governor.token()) == address(token), "BAD_TOKEN");
        return true;
    }
}


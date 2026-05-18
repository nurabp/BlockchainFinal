// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { GovernanceToken } from "../token/GovernanceToken.sol";
import { SimpleTimelock } from "./SimpleTimelock.sol";

contract ProtocolGovernor {
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Queued,
        Executed
    }

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        bytes32 salt;
        uint256 start;
        uint256 end;
        uint256 forVotes;
        uint256 againstVotes;
        bool queued;
        bool executed;
        string description;
    }

    GovernanceToken public immutable token;
    SimpleTimelock public immutable timelock;
    uint256 public constant VOTING_DELAY = 1 days;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant QUORUM_BPS = 400;
    uint256 public constant PROPOSAL_THRESHOLD_BPS = 100;
    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(
        uint256 indexed id, address indexed proposer, address target, string description
    );
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 weight);
    event ProposalQueued(uint256 indexed id, bytes32 operationId);
    event ProposalExecuted(uint256 indexed id);

    constructor(GovernanceToken token_, SimpleTimelock timelock_) {
        token = token_;
        timelock = timelock_;
    }

    function propose(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external returns (uint256 id) {
        require(
            token.votingPower(msg.sender) * 10_000 >= token.totalSupply() * PROPOSAL_THRESHOLD_BPS,
            "THRESHOLD"
        );
        id = ++proposalCount;
        proposals[id] = Proposal({
            proposer: msg.sender,
            target: target,
            value: value,
            data: data,
            salt: keccak256(abi.encode(msg.sender, id, description)),
            start: block.timestamp + VOTING_DELAY,
            end: block.timestamp + VOTING_DELAY + VOTING_PERIOD,
            forVotes: 0,
            againstVotes: 0,
            queued: false,
            executed: false,
            description: description
        });
        emit ProposalCreated(id, msg.sender, target, description);
    }

    function castVote(uint256 id, bool support) external {
        Proposal storage p = proposals[id];
        require(block.timestamp >= p.start && block.timestamp <= p.end, "VOTE_CLOSED");
        require(!hasVoted[id][msg.sender], "ALREADY_VOTED");
        uint256 weight = token.votingPower(msg.sender);
        require(weight > 0, "NO_VOTES");
        hasVoted[id][msg.sender] = true;
        if (support) p.forVotes += weight;
        else p.againstVotes += weight;
        emit VoteCast(msg.sender, id, support, weight);
    }

    function queue(uint256 id) external returns (bytes32 operationId) {
        Proposal storage p = proposals[id];
        require(state(id) == ProposalState.Succeeded, "NOT_SUCCEEDED");
        p.queued = true;
        operationId = timelock.schedule(p.target, p.value, p.data, p.salt);
        emit ProposalQueued(id, operationId);
    }

    function execute(uint256 id) external payable {
        Proposal storage p = proposals[id];
        require(state(id) == ProposalState.Queued, "NOT_QUEUED");
        p.executed = true;
        bytes memory result = timelock.execute{ value: p.value }(p.target, p.value, p.data, p.salt);
        result;
        emit ProposalExecuted(id);
    }

    function state(uint256 id) public view returns (ProposalState) {
        Proposal storage p = proposals[id];
        require(p.proposer != address(0), "UNKNOWN_PROPOSAL");
        if (p.executed) return ProposalState.Executed;
        if (p.queued) return ProposalState.Queued;
        if (block.timestamp < p.start) return ProposalState.Pending;
        if (block.timestamp <= p.end) return ProposalState.Active;
        uint256 quorum = token.totalSupply() * QUORUM_BPS / 10_000;
        return p.forVotes >= quorum && p.forVotes > p.againstVotes
            ? ProposalState.Succeeded
            : ProposalState.Defeated;
    }
}

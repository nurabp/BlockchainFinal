import { BigInt } from "@graphprotocol/graph-ts";
import { Deposit } from "../../generated/RwaVault/RwaVault";
import { Swap as SwapEvent } from "../../generated/AMM/ConstantProductAMM";
import { CollateralIssued } from "../../generated/GovernanceToken/GovernanceToken";
import {
  ProposalCreated,
  ProposalExecuted,
  ProposalQueued,
  VoteCast
} from "../../generated/Governor/ProtocolGovernor";
import { Proposal, Swap, Token, VaultDeposit } from "../../generated/schema";

export function handleDeposit(event: Deposit): void {
  let entity = new VaultDeposit(event.transaction.hash.concatI32(event.logIndex.toI32()));
  entity.caller = event.params.caller;
  entity.owner = event.params.owner;
  entity.assets = event.params.assets;
  entity.shares = event.params.shares;
  entity.blockNumber = event.block.number;
  entity.save();
}

export function handleSwap(event: SwapEvent): void {
  let entity = new Swap(event.transaction.hash.concatI32(event.logIndex.toI32()));
  entity.trader = event.params.trader;
  entity.tokenIn = event.params.tokenIn;
  entity.amountIn = event.params.amountIn;
  entity.amountOut = event.params.amountOut;
  entity.blockNumber = event.block.number;
  entity.save();
}

export function handleCollateralIssued(event: CollateralIssued): void {
  let entity = Token.load(event.address);
  if (entity == null) {
    entity = new Token(event.address);
    entity.symbol = "RWAG";
    entity.totalSupply = BigInt.zero();
  }
  entity.totalSupply = entity.totalSupply.plus(event.params.amount);
  entity.save();
}

export function handleProposalCreated(event: ProposalCreated): void {
  let entity = new Proposal(event.params.id.toString());
  entity.proposer = event.params.proposer;
  entity.target = event.params.target;
  entity.description = event.params.description;
  entity.forVotes = BigInt.zero();
  entity.againstVotes = BigInt.zero();
  entity.state = "Pending";
  entity.save();
}

export function handleVoteCast(event: VoteCast): void {
  let entity = Proposal.load(event.params.proposalId.toString());
  if (entity == null) return;
  if (event.params.support) {
    entity.forVotes = entity.forVotes.plus(event.params.weight);
  } else {
    entity.againstVotes = entity.againstVotes.plus(event.params.weight);
  }
  entity.state = "Active";
  entity.save();
}

export function handleProposalQueued(event: ProposalQueued): void {
  let entity = Proposal.load(event.params.id.toString());
  if (entity == null) return;
  entity.state = "Queued";
  entity.save();
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let entity = Proposal.load(event.params.id.toString());
  if (entity == null) return;
  entity.state = "Executed";
  entity.save();
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AggregatorV3Interface } from "../interfaces/AggregatorV3Interface.sol";

contract ChainlinkOracleAdapter {
    AggregatorV3Interface public immutable feed;
    uint256 public immutable maxStaleness;

    error StalePrice(uint256 updatedAt, uint256 nowTime);
    error BadPrice();

    constructor(address feed_, uint256 maxStaleness_) {
        feed = AggregatorV3Interface(feed_);
        maxStaleness = maxStaleness_;
    }

    function latestPrice() external view returns (uint256 price, uint8 decimals) {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();
        if (answeredInRound < roundId || startedAt > updatedAt) revert BadPrice();
        if (answer <= 0) revert BadPrice();
        if (updatedAt + maxStaleness < block.timestamp) {
            revert StalePrice(updatedAt, block.timestamp);
        }
        return (uint256(answer), feed.decimals());
    }
}

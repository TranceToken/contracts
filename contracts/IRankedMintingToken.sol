// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IRankedMintingToken {
    event RankedClaimed(address indexed user, uint256 term, uint256 rank);

    event MintClaimed(address indexed user, uint256 rewardAmount);

    function claimMintReward() external;
}
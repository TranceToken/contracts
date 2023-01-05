// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IRankedMintingToken {

    event MintClaimed(address indexed user, uint256 rewardAmount);

    function claimMintReward() external;
}

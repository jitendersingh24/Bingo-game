// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IBingo {
    event GameStarted(uint8 gameId);
    event JoinedGame(uint8 gameId, address gamer);
    event ClaimedReward(uint8 gameId, address winner);
    event NumberCrossed(uint8 gameId, uint8 crossedNumber, address gamer);
    event RandomNumberDrawn(uint8 gameId, uint8 randomNumber);

    function getAvailableGames() external view returns (uint8[] memory);
    function startGame() external returns (uint8);
    function joinGame(uint8 gameId, address erc20Contract) external;
    function claimReward(uint8 gameId, address erc20Contract) external;
    function cutNumber(uint8 gameId, uint8 randomNumber) external;
    function drawRandomNumber(uint8 gameId) external;
    function getDrawnNumber(uint8 gameId) external view returns (uint8);
}

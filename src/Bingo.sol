// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IBingo.sol";
import "./ERC20Contract.sol";
import {console} from "forge-std/console.sol";

contract Bingo is IBingo {
    struct gameDurationInfo {
        uint256 joinDuration;
        uint256 turnDuration;
        uint256 gameStartTimestamp;
        uint256 turnTimestamp;
    }

    // bit masking state variables
    // mapping of bingo state of players in a game
    mapping(uint8 => mapping(address => bytes32)) public gameState1;
    // mapping of drawn numbers on bingo of players
    mapping(uint8 => mapping(address => bytes32)) public drawnState1;
    // mapping of game and duration info
    mapping(uint8 => gameDurationInfo) public gameInfo;
    // mapping of game and drawn number
    mapping(uint8 => uint8[]) public drawnNumbers;
    // mapping of game and winning amount
    mapping(uint8 => uint256) public gameBalances;

    uint8[] public availableGames;

    address public owner;
    uint8 public nextGameId = 0;

    uint256 public _joinDuration = 1;
    uint256 public _turnDuration = 1;
    uint256 fee = 100;
    uint256 salt = 1;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Permission denied: Only owner can perform this operation!");
        _;
    }

    modifier onlyDuringJoinDuration(uint8 gameId) {
        // require(block.timestamp < gameInfo[gameId].joinDuration, "Game already started!");
        _;
    }

    modifier onlyDuringTurnDuration(uint8 gameId) {
        // require(block.timestamp > gameInfo[gameId].turnDuration, "Can't draw number right now!");
        _;
    }

    /**
     * @notice provides array of available games
     * @dev returns available games array
     */
    function getAvailableGames() external view returns (uint8[] memory) {
        uint8[] memory games = new uint8[](availableGames.length);
        games = availableGames;
        return games;
    }

    /**
     * @notice make a new game session
     * @dev initializes all game states required for a new game
     */
    function startGame() external onlyOwner returns (uint8) {
        uint8 gameId = _getNextGameId();
        gameInfo[gameId].joinDuration = _joinDuration;
        gameInfo[gameId].turnDuration = _turnDuration;
        availableGames.push(gameId);

        return gameId;
    }

    /**
     * @dev checks if a user is able to join the game and initializes random bingo
     * @param gameId ID of the game to be joined
     */
    function joinGame(uint8 gameId, address erc20Contract) external onlyDuringJoinDuration(gameId) {
        ERC20Contract(erc20Contract).transferFrom(msg.sender, address(this), 100);
        gameBalances[gameId] += 100;

        // generating random bingo for the new player
        _generateRandomBingoWithBitMasking(gameId, msg.sender);
        _generateDrawnStateBingoWithBitMasking(gameId, msg.sender);
    }

    /**
     * @dev function to claim reward
     * @param gameId ID of the game
     * @param erc20Contract ERC20 token contract address
     */
    function claimReward(uint8 gameId, address erc20Contract) external {
        require(
            _checkGameStateWithBitMaskingToClaimReward(gameId, msg.sender),
            "Game state is not winnable: Can't claim reward!"
        );
        _transferWinnersAmount(msg.sender, erc20Contract, gameId);
    }

    /**
     * @dev function to cross word in drawn matrix
     * @param gameId ID of the game
     * @param randomNumber random number to be crossed in bingo
     */
    function cutNumber(uint8 gameId, uint8 randomNumber) external {
        (uint8[5][5] memory playerMatrix,) = _getPlayerAndMarkedMatrix(gameId, msg.sender);
        uint256 markedMatrixSlot = uint256(keccak256(abi.encode(msg.sender, keccak256(abi.encode(gameId, uint256(1))))));
        bytes32 value;

        for (uint8 i = 0; i < 5;) {
            for (uint8 j = 0; j < 5;) {
                uint8 shiftLength = (i * 8 * 5) + (j * 8);

                if (playerMatrix[i][j] == randomNumber) {
                    assembly {
                        value := or(shl(shiftLength, 1), sload(markedMatrixSlot))
                        sstore(markedMatrixSlot, value)
                    }
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev drawing random number
     * @param gameId ID of the game
     */
    function drawRandomNumber(uint8 gameId) external onlyOwner {
        drawnNumbers[gameId].push(_getNextRandomNumber());
    }

    /**
     * @dev get recently drawn number
     * @param gameId ID of the game
     */
    function getDrawnNumber(uint8 gameId) external view returns (uint8) {
        return drawnNumbers[gameId][drawnNumbers[gameId].length - 1];
    }

    /**
     * @dev updates and returns next game ID
     */
    function _getNextGameId() internal returns (uint8) {
        ++nextGameId;
        return nextGameId;
    }

    /**
     * @dev provides next random number drawn
     */
    function _getNextRandomNumber() internal returns (uint8) {
        uint8 randomNumber = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), salt))) % 256);
        ++salt;
        return randomNumber;
    }

    /**
     * @dev generate a random bingo using bit masking
     * @param gameId ID of the game
     * @param gamer address of the player
     */
    function _generateRandomBingoWithBitMasking(uint8 gameId, address gamer) internal returns (bytes32 byteValue) {
        bytes32 value;
        uint256 slot = uint256(keccak256(abi.encode(gamer, keccak256(abi.encode(gameId, uint256(0))))));

        for (uint8 i = 0; i < 25;) {
            uint8 randomNumber = _getNextRandomNumber();
            uint8 byteLength = i * 8;

            assembly {
                value := sload(slot)
                value := or(shl(byteLength, randomNumber), value)
                sstore(slot, value)
            }

            unchecked {
                ++i;
            }
        }

        return value;
    }

    /**
     * @dev generate initial drawn state using bit masking
     * @param gameId ID of the game
     * @param gamer address of the player
     */
    function _generateDrawnStateBingoWithBitMasking(uint8 gameId, address gamer) internal returns (bytes32) {
        bytes32 value;
        uint8 boolValue = 0;
        uint256 slot = uint256(keccak256(abi.encode(gamer, keccak256(abi.encode(gameId, uint256(1))))));

        for (uint8 i = 0; i < 25;) {
            uint8 byteLength = i * 8;

            if (i == 12) {
                boolValue = 1;
            } else {
                boolValue = 0;
            }

            assembly {
                value := sload(slot)
                value := or(shl(byteLength, boolValue), value)
                sstore(slot, value)
            }

            unchecked {
                ++i;
            }
        }

        return value;
    }

    /**
     * @dev function to retrieve player matrix and marked matrix from bit manipulated slots
     * @param gameId ID of the game
     * @param gamer address of the gamer
     * @return playerMatrix matrix provided to the player
     * @return drawnMatrix matrix updated by the player
     */
    function _getPlayerAndMarkedMatrix(uint8 gameId, address gamer)
        internal
        view
        returns (uint8[5][5] memory, bool[5][5] memory)
    {
        uint256 gameStateSlot = uint256(keccak256(abi.encode(gamer, keccak256(abi.encode(gameId, uint256(0))))));
        uint256 drawnStateSlot = uint256(keccak256(abi.encode(gamer, keccak256(abi.encode(gameId, uint256(1))))));
        bytes32 gameStateMaskedValue;
        bytes32 drawnStateMaskedValue;

        assembly {
            gameStateMaskedValue := sload(gameStateSlot)
            drawnStateMaskedValue := sload(drawnStateSlot)
        }

        uint8[5][5] memory playerMatrix;
        bool[5][5] memory drawnMatrix;
        for (uint8 i = 0; i < 5;) {
            for (uint8 j = 0; j < 5;) {
                uint8 stateNumber;
                uint8 drawnFlag;
                uint8 shiftLength = (i * 8 * 5) + (j * 8);

                assembly {
                    stateNumber := shr(shiftLength, gameStateMaskedValue)
                    drawnFlag := shr(shiftLength, drawnStateMaskedValue)
                }

                playerMatrix[i][j] = stateNumber;
                drawnMatrix[i][j] = drawnFlag == 0 ? false : true;

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        return (playerMatrix, drawnMatrix);
    }

    /**
     * @dev transfer winners amount
     * @param winner address of the winner
     * @param erc20Contract ERC20 token contract address
     * @param gameId ID of the game
     */
    function _transferWinnersAmount(address winner, address erc20Contract, uint8 gameId) private {
        ERC20Contract(erc20Contract).transfer(winner, gameBalances[gameId]);
    }

    /**
     * @dev checking state if game for a potential winner
     * @param gameId ID of the game
     * @param gamer address of the gamer
     */
    function _checkGameStateWithBitMaskingToClaimReward(uint8 gameId, address gamer) private view returns (bool) {
        (uint8[5][5] memory playerMatrix, bool[5][5] memory markedMatrix) = _getPlayerAndMarkedMatrix(gameId, gamer);
        uint8[] memory drawnNumbersArray = drawnNumbers[gameId];
        uint8 totalLinesCrossed = 0;

        // rows crossed and player matrix validity
        for (uint8 i = 0; i < 5; ++i) {
            bool isRowCrossed = true;

            for (uint8 j = 0; j < 5; ++j) {
                if (i == 2 && j == 2) {
                    continue;
                } else if (markedMatrix[i][j] == true) {
                    bool flag = false;
                    for (uint256 k = 0; k < drawnNumbersArray.length; ++k) {
                        if (drawnNumbersArray[k] == playerMatrix[i][j]) {
                            flag = true;
                        }
                    }

                    require(flag, "Faulty matrix provided!");
                } else {
                    isRowCrossed = false;
                }
            }

            if (isRowCrossed) {
                ++totalLinesCrossed;
                if (totalLinesCrossed >= 5) {
                    return true;
                }
            }
        }

        // column crossed
        for (uint8 j = 0; j < 5; ++j) {
            bool isColumnCrossed = true;

            for (uint8 i = 0; i < 5; ++i) {
                if (!markedMatrix[i][j]) {
                    isColumnCrossed = false;
                }
            }

            if (isColumnCrossed) {
                ++totalLinesCrossed;
                if (totalLinesCrossed >= 5) {
                    return true;
                }
            }
        }

        // first diagonal crossed
        bool isDiagonalCrossed = true;
        for (uint8 i = 0; i < 5; i++) {
            if (!markedMatrix[i][i]) {
                isDiagonalCrossed = false;
            }
        }

        if (isDiagonalCrossed) {
            ++totalLinesCrossed;
            if (totalLinesCrossed >= 5) {
                return true;
            }
        }

        // second diagonal crossed
        isDiagonalCrossed = false;
        for (uint8 i = 0; i < 5; ++i) {
            if (!markedMatrix[4 - i][i]) {
                isDiagonalCrossed = false;
            }
        }

        if (isDiagonalCrossed) {
            ++totalLinesCrossed;
            if (totalLinesCrossed >= 5) {
                return true;
            }
        }

        return false;
    }
}

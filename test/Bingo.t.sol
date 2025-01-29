// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import "../src/Bingo.sol";
import "../src/ERC20Contract.sol";

contract BingoTest is Test {
    Bingo public bingo;
    ERC20Contract public erc20Contract;
    address public bingoOwner;
    address public dummy1;
    address public dummy2;

    function setUp() public {
        bingo = new Bingo();
        bingoOwner = address(this);
        erc20Contract = new ERC20Contract(10000);    // 10000 initial supply
        
        dummy1 = address(1);
        dummy2 = address(2);
    }

    function test_startGame() public {
        uint8 gameId = bingo.startGame();
        assertEq(gameId, 1);
        
        assertEq(bingo._joinDuration(), 1);
        assertEq(bingo._turnDuration(), 1);
        assertEq(bingo.availableGames(0), 1);
    }

    function test_joinGame() public {
        uint8 gameId = bingo.startGame();

        erc20Contract.mint(dummy1, 1000);

        vm.startPrank(dummy1);
        // transferring entry fee to bingo contract
        erc20Contract.approve(address(bingo), 100);
        bingo.joinGame(gameId, address(erc20Contract));

        assertEq(erc20Contract.balanceOf(address(bingo)), 100);
    }

    function test_playFunctionality() public {
        uint8 gameId = bingo.startGame();

        erc20Contract.mint(dummy1, 100);

        vm.startPrank(dummy1);
        // transferring entry fee to bingo contract
        erc20Contract.approve(address(bingo), 100);
        bingo.joinGame(gameId, address(erc20Contract));

        vm.stopPrank();

        for (uint i = 0; i < 1000; ++i) {
            bingo.drawRandomNumber(gameId);
            uint8 drawnNumber = bingo.getDrawnNumber(gameId);

            vm.startPrank(dummy1);
            bingo.cutNumber(gameId, drawnNumber);
            vm.stopPrank();
        }

        vm.startPrank(dummy1);
        bingo.claimReward(gameId, address(erc20Contract));
        vm.stopPrank();

        assertEq(erc20Contract.balanceOf(dummy1), 100);
    }

    function test_generateRandomBingoWithBitMasking() public {
        uint8 gameId = bingo.startGame();

        erc20Contract.mint(dummy1, 1000);

        vm.startPrank(dummy1);
        // transferring entry fee to bingo contract
        erc20Contract.approve(address(bingo), 100);
        bingo.joinGame(gameId, address(erc20Contract));

        vm.stopPrank();

        for (uint i = 0; i < 50; ) {
            bingo.drawRandomNumber(gameId);

            unchecked {
                ++i;
            }
        }
    }
}
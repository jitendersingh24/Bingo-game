// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title dummy ERC20 token contract
 * @author 
 * @notice initializing and minting tokens to dummy erc20 contract
 */
contract ERC20Contract is ERC20 {
    constructor(uint256 initialSupply) ERC20("bitcoin", "BTC") {
        _mint(address(this), initialSupply);
    }

    function mint(address account, uint256 value) public {
        _mint(account, value);
    }
}
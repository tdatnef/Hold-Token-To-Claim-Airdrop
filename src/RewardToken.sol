// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract RewardToken is ERC20, ERC20Permit {
    constructor() ERC20("RWD", "RWD") ERC20Permit("RWD") {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}

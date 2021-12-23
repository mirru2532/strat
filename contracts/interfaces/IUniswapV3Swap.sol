pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

interface IUniswapV3Swap {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    function quoteExactInput(bytes calldata path, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);
}

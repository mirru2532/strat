pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

library Dexes {
    uint256 internal constant CHAIN_ID = 1;

    // Uniswap V2 router
    address public constant UNISWAP_V2 =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // Sushiswap router
    address public constant SUSHISWAP =
        0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    // Uniswap V3 router
    address public constant UNISWAP_V3 =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;
}

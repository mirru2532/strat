pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

library Oracles {
    uint256 internal constant CHAIN_ID = 1;

    // Uniswap V3 Quoter contract for getting price data
    address public constant UNISWAP_V3_QUOTER =
        0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
}

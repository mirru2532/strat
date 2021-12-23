pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

library Coins {
    uint256 internal constant CHAIN_ID = 1;

    address public constant CVX =
        address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    address public constant CRV =
        address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address public constant WETH =
        address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant DAI =
        address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address public constant USDC =
        address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDT =
        address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
}

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Coins} from "./Coins.sol";

library Convex {
    uint256 internal constant CHAIN_ID = 1;

    /// @notice Convex Booster contract
    ///         from https://docs.convexfinance.com/convexfinance/faq/contract-addresses
    address public constant BOOSTER =
        0xF403C135812408BFbE8713b5A23a04b3D48AAE31;

    function getCVXMintAmount(uint256 crvEarned)
        internal
        view
        returns (uint256)
    {
        uint256 cliffSize = 1e23;
        uint256 cliffCount = 1000;
        uint256 maxSupply = 1e26;
        uint256 cvxTotalSupply = IERC20(Coins.CRV).totalSupply();
        uint256 currentCliff = cvxTotalSupply / cliffSize;

        if (currentCliff < cliffCount) {
            uint256 remaining = cliffCount - currentCliff;

            uint256 cvxEarned = (crvEarned * remaining) / cliffCount;

            uint256 amountTillMax = maxSupply - cvxTotalSupply;

            if (cvxEarned > amountTillMax) {
                cvxEarned = amountTillMax;
            }
            return cvxEarned;
        }

        return 0;
    }
}

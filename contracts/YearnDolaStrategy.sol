// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// Contracts
import "./base/BaseConvexMetapoolStrategy.sol";

// Interfaces
import "./interfaces/IInvestZap.sol";

contract Strategy is BaseConvexMetapoolStrategy {
    // get replaced during compilation, viewable from base class public vars
    address private constant _DOLA3POOL3CRV =
        0xAA5A67c256e27A5d80712c51971408db3370927D;
    address private constant _DOLA_CONVEX_REWARDS =
        0x835f69e58087E5B6bffEf182fe2bf959Fe253c3c;
    uint256 private constant _DOLA_CONVEX_REWARD_POOL_ID = 62;

    // have getters
    address public constant TRIPOOL_ZAP =
        0xA79828DF1850E8a3A3064576f380D90aECDD3359;

    address[] public underlyingCoinsForDepositing;
    uint256[] public uniswapV3PoolFeesForUnderlying;

    constructor(
        address _vault,
        uint256[2] memory _dexIds,
        uint24[3] memory _uniswapV3PoolFees,
        address[2] memory _underlyingCoinsForDepositing,
        uint256[2] memory _uniswapV3PoolFeesForUnderlying,
        BaseStrategySettings memory settings
    )
        public
        BaseConvexMetapoolStrategy(
            _vault,
            TRIPOOL_ZAP,
            _DOLA_CONVEX_REWARDS,
            _DOLA_CONVEX_REWARD_POOL_ID,
            _dexIds,
            _uniswapV3PoolFees,
            settings
        )
    {
        underlyingCoinsForDepositing = _underlyingCoinsForDepositing;
        uniswapV3PoolFeesForUnderlying = _uniswapV3PoolFeesForUnderlying;
    }

    function setUnderlyingCoinsForDepositing(uint256 coinId, address newCoin)
        external
        onlyAuthorized
    {
        underlyingCoinsForDepositing[coinId] = newCoin;
    }

    function setUniswapV3PoolFeesForUnderlying(uint256 coinId, uint24 newFee)
        external
        onlyAuthorized
    {
        uniswapV3PoolFeesForUnderlying[coinId] = newFee;
    }

    function ethToWant(uint256 _amtInWei)
        public
        view
        override
        returns (uint256)
    {
        if (_amtInWei == 0) return 0;

        address[] memory path = new address[](2);
        path[0] = Coins.WETH;
        path[1] = Coins.DAI;

        return
            IInvestZap(TRIPOOL_ZAP).calc_token_amount(
                _DOLA3POOL3CRV,
                [0, _getAmountOutByDex(_amtInWei, 1, path), 0, 0],
                true
            );
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        virtual
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        uint256 initialWantBalance = balanceOfWant();

        IConvexRewardPool(rewardsPool).getReward(
            address(this),
            claimConvexRewards
        );

        uint256 crvEarned = IERC20(Coins.CRV).balanceOf(address(this));

        if (crvEarned > 0) {
            crvEarned = _adjustCRV(crvEarned);

            address[] memory path = new address[](3);
            path[0] = Coins.CRV;
            path[1] = Coins.WETH;
            path[2] = underlyingCoinsForDepositing[0];

            _swapTokensByDex(0, crvEarned, path);
        }

        uint256 cvxEarned = IERC20(Coins.CVX).balanceOf(address(this));

        if (cvxEarned > 0) {
            address[] memory path = new address[](3);

            path[0] = Coins.CVX;
            path[1] = Coins.WETH;
            path[2] = underlyingCoinsForDepositing[1];

            _swapTokensByDex(1, cvxEarned, path);
        }

        uint256 balanceDAI = IERC20(Coins.DAI).balanceOf(address(this));
        uint256 balanceUSDC = IERC20(Coins.USDC).balanceOf(address(this));
        uint256 balanceUSDT = IERC20(Coins.USDT).balanceOf(address(this));

        if (balanceDAI + balanceUSDT + balanceUSDC > 0) {
            IInvestZap(TRIPOOL_ZAP).add_liquidity(
                _DOLA3POOL3CRV,
                [0, balanceDAI, balanceUSDC, balanceUSDT],
                0
            );
        }

        uint256 newWantBalance = want.balanceOf(address(this));

        uint256 profit = newWantBalance.sub(initialWantBalance);
        uint256 totalAssets = newWantBalance.add(balanceOfPool());

        uint256 debt = vault.strategies(address(this)).totalDebt;

        if (totalAssets < debt) {
            _loss = debt - totalAssets;
            _profit = 0;
        }

        if (_debtOutstanding > 0) {
            _withdraw(_debtOutstanding);
            _debtPayment = Math.min(
                _debtOutstanding,
                newWantBalance.sub(_profit)
            );
        }
    }

    function _swapTokensByDex(
        uint256 coinId,
        uint256 amountIn,
        address[] memory path
    ) internal {
        uint256 dexId = dexIds[coinId];

        if (dexId < 2) {
            IUniswapV2Swap(dexes[dexId]).swapExactTokensForTokens(
                amountIn,
                uint256(0),
                path,
                address(this),
                now
            );
            return;
        }

        bytes memory bytesPath =
            abi.encode(
                path[0],
                uniswapV3PoolFees[coinId],
                path[1],
                uniswapV3PoolFeesForUnderlying[coinId],
                path[2]
            );

        IUniswapV3Swap(dexes[dexId]).exactInput(
            IUniswapV3Swap.ExactInputParams({
                path: bytesPath,
                recipient: address(this),
                deadline: now,
                amountIn: amountIn,
                amountOutMinimum: uint256(0)
            })
        );
    }
}

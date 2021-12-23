pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {
    BaseStrategyInitializable,
    StrategyParams
} from "@yearnvaults/contracts/BaseStrategy.sol";

import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import {Math} from "@openzeppelin/contracts/math/Math.sol";

// libraries
import "../libraries/Coins.sol";
import "../libraries/Convex.sol";
import "../libraries/Dexes.sol";
import "../libraries/Oracles.sol";
import "../libraries/Yearn.sol";

// rest interfaces
import "../interfaces/IBooster.sol";
import "../interfaces/IConvexRewardPool.sol";
import "../interfaces/ICurvePool.sol";
import "../interfaces/IUniswapV2Swap.sol";
import "../interfaces/IUniswapV3Swap.sol";
import "../interfaces/IERC20Metadata.sol";

struct BaseStrategySettings {
    uint192 debtThreshold;
    uint64 denominator;
    uint64 minReportDelay;
    uint64 maxReportDelay;
    uint64 profitFactor;
    uint64 voterCRVShare;
}

abstract contract BaseConvexMetapoolStrategy is BaseStrategyInitializable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public immutable metapool;
    uint256 public immutable poolId;

    uint256 public voterCRVShare;
    uint256 public denominator;

    bool public claimConvexRewards;
    address public rewardsPool;

    address[] public dexes = [
        Dexes.UNISWAP_V2,
        Dexes.SUSHISWAP,
        Dexes.UNISWAP_V3
    ];

    uint256[] public dexIds;
    uint24[] public uniswapV3PoolFees;

    constructor(
        address _vault,
        address _metapool,
        address _rewardsPool,
        uint256 _poolId,
        uint256[2] memory _dexIds,
        uint24[3] memory _uniswapV3PoolFees,
        BaseStrategySettings memory settings
    ) public BaseStrategyInitializable(_vault) {
        minReportDelay = settings.minReportDelay;
        maxReportDelay = settings.maxReportDelay;

        profitFactor = settings.profitFactor;
        debtThreshold = settings.debtThreshold;

        voterCRVShare = settings.voterCRVShare;
        denominator = settings.denominator;

        uniswapV3PoolFees = _uniswapV3PoolFees;

        claimConvexRewards = true;

        metapool = _metapool;
        rewardsPool = _rewardsPool;

        dexIds = _dexIds;
        poolId = _poolId;

        _safeApprove(want, Convex.BOOSTER, type(uint256).max);

        _safeApprove(IERC20(Coins.DAI), _metapool, type(uint256).max);
        _safeApprove(IERC20(Coins.USDC), _metapool, type(uint256).max);
        _safeApprove(IERC20(Coins.USDT), _metapool, type(uint256).max);

        _safeApprove(IERC20(Coins.CRV), dexes[_dexIds[0]], type(uint256).max);
        _safeApprove(IERC20(Coins.CVX), dexes[_dexIds[1]], type(uint256).max);
    }

    function setVoterCRVShare(uint256 _newVoterCrvShare)
        external
        onlyAuthorized
    {
        voterCRVShare = _newVoterCrvShare;
    }

    function setDex(uint256 _coinId, uint256 _dexId) external onlyAuthorized {
        dexIds[_coinId] = _dexId;
        if (_coinId == 0)
            _safeApprove(IERC20(Coins.CRV), dexes[_dexId], type(uint256).max);
        else _safeApprove(IERC20(Coins.CVX), dexes[_dexId], type(uint256).max);
    }

    function setUniswapV3PoolFee(uint256 _feeId, uint24 _newFee)
        external
        onlyAuthorized
    {
        uniswapV3PoolFees[_feeId] = _newFee;
    }

    function setClaimConvexRewards() external onlyAuthorized {
        claimConvexRewards = !claimConvexRewards;
    }

    function exitConvexRewards() external onlyAuthorized {
        IConvexRewardPool rewards = IConvexRewardPool(rewardsPool);
        uint256 staked = rewards.balanceOf(address(this));
        rewards.withdraw(staked, claimConvexRewards);
    }

    function approveSpending(
        IERC20 _coin,
        address _spender,
        uint256 _amount
    ) external onlyAuthorized {
        _safeApprove(_coin, _spender, _amount);
    }

    function name() external view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "Convex",
                    IERC20Metadata(address(want)).symbol()
                )
            );
    }

    function balanceOfWant() public view returns (uint256) {
        return want.balanceOf(address(this));
    }

    function balanceOfPool() public view returns (uint256) {
        return IConvexRewardPool(rewardsPool).balanceOf(address(this));
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    function _safeApprove(
        IERC20 _coin,
        address _spender,
        uint256 _amount
    ) internal {
        _coin.safeApprove(_spender, _amount);
    }

    function liquidateAllPositions()
        internal
        override
        returns (uint256 _amountFreed)
    {
        (_amountFreed, ) = liquidatePosition(balanceOfPool());
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        if (emergencyExit) return;
        uint256 _want = want.balanceOf(address(this));

        if (_want > 0) {
            IBooster(Convex.BOOSTER).deposit(poolId, _want, true);
        }
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        uint256 _balance = balanceOfWant();
        if (_balance < _amountNeeded) {
            _liquidatedAmount = _withdraw(_amountNeeded.sub(_balance));
            _liquidatedAmount = _liquidatedAmount.add(_balance);
            _loss = _amountNeeded.sub(_liquidatedAmount);
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    function _migrateRewards(address _newStrategy) internal {
        IERC20(Coins.CRV).safeTransfer(
            _newStrategy,
            IERC20(Coins.CRV).balanceOf(address(this))
        );
        IERC20(Coins.CVX).safeTransfer(
            _newStrategy,
            IERC20(Coins.CVX).balanceOf(address(this))
        );
    }

    function prepareMigration(address _newStrategy) internal override {
        IConvexRewardPool(rewardsPool).withdrawAllAndUnwrap(claimConvexRewards);
        _migrateRewards(_newStrategy);
    }

    function _withdraw(uint256 _amount) internal returns (uint256) {
        _amount = Math.min(_amount, balanceOfPool());
        uint256 _before = balanceOfWant();
        IConvexRewardPool(rewardsPool).withdrawAndUnwrap(_amount, false);
        return balanceOfWant().sub(_before);
    }

    function _adjustCRV(uint256 _crvBalance) internal returns (uint256) {
        uint256 _crvToTransfer =
            _crvBalance.mul(voterCRVShare).div(denominator);
        if (_crvToTransfer > 0)
            IERC20(Coins.CRV).safeTransfer(Yearn.YCRV_VOTER, _crvToTransfer);
        return _crvBalance.sub(_crvToTransfer);
    }

    function protectedTokens()
        internal
        view
        virtual
        override
        returns (address[] memory)
    {
        address[] memory protected = new address[](2);
        protected[0] = Coins.CRV;
        protected[1] = Coins.CVX;
        return protected;
    }

    function _claimableInETH() internal view virtual returns (uint256) {
        uint256 _crvEarned =
            IConvexRewardPool(rewardsPool).earned(address(this));
        uint256 _cvxEarned = Convex.getCVXMintAmount(_crvEarned);

        uint256 crvValue;
        uint256 cvxValue;

        if (_crvEarned > 0) {
            address[] memory path = new address[](2);
            path[0] = Coins.CRV;
            path[1] = Coins.WETH;
            crvValue = _getAmountOutByDex(_crvEarned, 0, path);
        }

        if (_cvxEarned > 0) {
            address[] memory path = new address[](2);
            path[0] = Coins.CVX;
            path[1] = Coins.WETH;

            cvxValue = _getAmountOutByDex(_cvxEarned, 1, path);
        }

        return crvValue.add(cvxValue);
    }

    function _getAmountOutByDex(
        uint256 amount,
        uint256 coinId,
        address[] memory path
    ) internal view returns (uint256) {
        uint256 dexId = dexIds[coinId];

        if (dexId < 2) {
            return IUniswapV2Swap(dexes[dexId]).getAmountsOut(amount, path)[0];
        }

        bytes memory data =
            abi.encode(path[0], path[1], uniswapV3PoolFees[coinId]);

        return
            IUniswapV3Swap(Oracles.UNISWAP_V3_QUOTER).quoteExactInput(
                data,
                amount
            );
    }
}

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

interface IConvexRewardPool {
    function pid() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function userRewardPerTokenPaid(address) external view returns (uint256);

    function extraRewardsLength() external view returns (uint256);

    function extraRewards(uint256) external view returns (address);

    function rewardPerToken() external view returns (uint256);

    function rewardPerTokenStored() external view returns (uint256);

    function rewardRate() external view returns (uint256);

    function rewardToken() external view returns (address);

    function rewards(address) external view returns (uint256);

    function stakingToken() external view returns (address);

    function stake(uint256) external returns (bool);

    function stakeAll() external returns (bool);

    function stakeFor(address, uint256) external returns (bool);

    function withdraw(uint256 amount, bool claim) external returns (bool);

    function withdrawAll(bool claim) external returns (bool);

    function withdrawAndUnwrap(uint256 amount, bool claim)
        external
        returns (bool);

    function withdrawAllAndUnwrap(bool claim) external;

    function getReward() external returns (bool);

    function getReward(address _account, bool _claimExtras)
        external
        returns (bool);

    function donate(uint256 _amount) external returns (bool);
}

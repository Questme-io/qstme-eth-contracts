// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @notice Sponsor data
/// @param recipient - address of the recipient
/// @param asset - asset that should be sent as reward
/// @param amount - amount of then asset that should be sent
/// @dev Zero address in asset should be treated as native token
struct Reward {
    address recipient;
    address asset;
    uint256 amount;
}

interface IQstmeReward {
    /// @notice Emitted when reward is sent
    /// @param recipient - address thar received reward
    /// @param amount - sponsored amount
    /// @param asset - sponsored asset
    /// @dev Zero address in asset should be treated as native token
    event Rewarded(
        address indexed recipient,
        address indexed asset,
        uint256 indexed amount
    );

    /// @notice Thrown when nonce check failed
    /// @param actual - actual nonce
    /// @param provided - provided nonce
    error NonceCollision(uint256 actual, uint256 provided);

    /// @notice Thrown when sender is not admin or operator
    error NotAnAdminOrOperator();

    /// @notice For receiving current nonce for recipient address
    /// @param recipient - address whose nonce should be returned
    /// @return nonce of the requested address
    function getNonce(address recipient) external returns(uint256);

    /// @notice Sends funds to the recipient
    /// @param recipient - address that should receive the reward
    /// @param asset - asset that should be used for reward
    /// @param amount - amount of the asset
    /// @param nonce - updated recipient nonce
    /// @param signature - signature of the reward digest
    function receiveReward(address recipient, address asset, uint256 amount, uint256 nonce, bytes calldata signature) external;

    /// @notice Sends funds to the recipient
    /// @param reward - reward data to send
    /// @dev Automatically increments nonce
    function reward(Reward calldata reward) external;

    /// @notice Sends funds to several recipients
    /// @param rewards - array of reward data to send
    /// @dev Automatically increments nonce for each reward
    function rewardBatch(Reward[] calldata rewards) external;

    /// @notice Generates digest with RewardParams
    /// @param recipient - address of the recipient
    /// @param asset - asset that should be used for reward
    /// @param amount - amount of the asset
    /// @param nonce - updated recipient nonce
    /// @return Digest for setting sponsor
    function generateRewardDigest(address recipient, address asset, uint256 amount, uint256 nonce) external view returns (bytes32);

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @notice Sponsor data
/// @param id - sponsor ID
/// @param nonce - nonce for avoiding signature reuse
/// @param asset - asset sponsor needs to pay
/// @param threshold - amount of asset sponsor needs to pay
/// @param payed - amount of asset sponsor has payed
/// @param fulfilledAt - timestamp when payed amount reached threshold
/// @dev If sponsor should pay in native token then asset would be zero address
struct Sponsor {
    bytes32 id;
    uint32 nonce;
    address asset;
    uint256 threshold;
    uint256 payed;
    uint256 fulfilledAt;
}

/// @notice Combined data for asset address and its amount
/// @param asset - asset address
/// @param amount - amount of asset
/// @dev For native token asset should be zero address
struct Asset {
    address assetAddress;
    uint256 amount;
}

interface IQstmeSponsor {
    /// @notice Emitted when sponsorship is paid
    /// @param sponsorId - id of sponsor
    /// @param amount - sponsored amount
    /// @param asset - sponsored asset
    /// @dev If sponsor paid in native token then asset would be zero address
    event Sponsored(bytes32 indexed sponsorId, uint256 indexed amount, address indexed asset);

    /// @notice Emitted when sponsored amount reaches threshold
    /// @param sponsorId - id of sponsor
    event SponsorFulfilled(bytes32 indexed sponsorId);

    /// @notice Emitted when sponsor is reset
    /// @param sponsorId - id of sponsor
    event SponsorReset(bytes32 indexed sponsorId);

    /// @notice Emitted when asset is withdrawn
    /// @param receiver - address to which asset was withdrawn
    /// @param asset - address of asser that was withdrawn
    /// @param amount - amount of asset that was withdrawn
    /// @dev Zero address asset represents native token
    event Withdrawn(address indexed receiver, address indexed asset, uint256 amount);

    /// @notice Thrown when sponsor does not exist
    /// @param id - provided sponsor id
    error SponsorDoesNotExists(bytes32 id);

    /// @notice Thrown when attempting to sponsor with invalid asset
    /// @param expected - expected asset
    /// @param provided - provided asset
    /// @dev Native token is zero address
    error InvalidAsset(address expected, address provided);

    /// @notice Thrown when attempting to sponsor with native token but providing wrong value
    /// @param expected - expected value
    /// @param received - received value
    error InvalidValue(uint256 expected, uint256 received);

    /// @notice Thrown when attempting to sponsor with ERC20 token but not providing enough allowance
    error NotEnoughAllowance(uint256 allowance, uint256 amount);

    /// @notice Thrown when nonce check failed
    /// @param actual - actual nonce
    /// @param provided - provided nonce
    error NonceCollision(uint32 actual, uint32 provided);

    /// @notice Get sponsor details
    /// @param id - sponsor id
    /// @return sponsor - sponsor details
    function getSponsor(bytes32 id) external view returns (Sponsor memory);

    /// @notice Set sponsor and sponsor it with native or ERC20 token
    /// @param id - sponsor id
    /// @param asset - asset that should be set for sponsor and used for sponsoring
    /// @param amount - amount of asset that should be used for sponsoring
    /// @param threshold - sponsor threshold
    /// @param nonce - sponsor nonce for avoiding signature reuse
    /// @param signature - operator signature with SponsorParams
    /// @dev if asset is zero address then native token will be used
    /// @dev if using native token then amount should be equal to msg.value
    function resetAndSendSponsorship(
        bytes32 id,
        address asset,
        uint256 amount,
        uint256 threshold,
        uint32 nonce,
        bytes calldata signature
    ) external payable;

    /// @notice Sponsor with native or ERC20 token
    /// @param id - sponsor id
    /// @param asset - asset that should be used for sponsoring
    /// @param amount - amount of asset that should be used for sponsoring
    /// @dev if asset is zero address then native token will be used
    /// @dev if using native token then amount should be equal to msg.value
    function sendSponsorship(bytes32 id, address asset, uint256 amount) external payable;

    /// @notice Generates digest for setting sponsor
    /// @param sponsorId - id of sponsor that should be set
    /// @param asset - asset that should be used for sponsoring
    /// @param threshold - threshold that should be used for sponsoring
    /// @param nonce - sponsor nonce for avoiding signature reuse
    /// @return Digest for setting sponsor
    function generateSponsorDigest(bytes32 sponsorId, address asset, uint256 threshold, uint32 nonce)
        external
        view
        returns (bytes32);

    /// @notice Withdraws asset from contract
    /// @param receiver - address to which asset should be withdrawn
    /// @param asset - asset that should be withdrawn
    function withdraw(address receiver, Asset calldata asset) external;

    /// @notice Withdraws several assets from contract
    /// @param receiver - address to which assets should be withdrawn
    /// @param assets - array of assets that should be withdrawn
    function withdrawBatch(address receiver, Asset[] calldata assets) external;
}

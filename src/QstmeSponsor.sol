// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EIP712} from "@openzeppelin-contracts-5.2.0/utils/cryptography/EIP712.sol";
import {AccessControl} from "@openzeppelin-contracts-5.2.0/access/AccessControl.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin-contracts-5.2.0/utils/cryptography/ECDSA.sol";

import "./interfaces/IQstmeSponsor.sol";

contract QstmeSponsor is IQstmeSponsor, AccessControl, EIP712 {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    string public constant NAME = "QstmeSponsor";
    string public constant VERSION = "0.0.1";

    /// @notice sponsors data
    mapping(bytes32 sponsorId => Sponsor) public sponsors;

    constructor(address _admin, address _operator) EIP712(NAME, VERSION) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _operator);
    }

    /// @inheritdoc IQstmeSponsor
    function getSponsor(bytes32 _sponsorId) external view returns (Sponsor memory) {
        return sponsors[_sponsorId];
    }

    /// @inheritdoc IQstmeSponsor
    function withdraw(address _receiver, Asset calldata _asset) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _withdraw(payable(_receiver), _asset);
    }

    /// @inheritdoc IQstmeSponsor
    function withdrawBatch(address _receiver, Asset[] calldata _assets) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _assets.length; i++) {
            _withdraw(payable(_receiver), _assets[i]);
        }
    }

    /// @inheritdoc IQstmeSponsor
    function resetAndSendSponsorship(
        bytes32 _sponsorId,
        address _asset,
        uint256 _amount,
        uint256 _threshold,
        uint32 _nonce,
        bytes calldata _signature
    ) external payable {
        _setSponsor(_sponsorId, _asset, _threshold, _nonce, _signature);

        sendSponsorship(_sponsorId, _asset, _amount);
    }

    /// @inheritdoc IQstmeSponsor
    function sendSponsorship(bytes32 _sponsorId, address _asset, uint256 _amount) public payable {
        if (_asset == address(0)) {
            if (_amount != msg.value) revert InvalidValue(_amount, msg.value);
        } else {
            uint256 allowance = IERC20(_asset).allowance(msg.sender, address(this));

            if (allowance < _amount) revert NotEnoughAllowance(allowance, _amount);

            IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        }

        _registerSponsorship(_sponsorId, _asset, _amount);
    }

    /// @inheritdoc IQstmeSponsor
    function generateSponsorDigest(bytes32 _sponsorId, address _asset, uint256 _threshold, uint32 _nonce) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("SponsorParams(bytes32 sponsorId,address asset,uint256 threshold)"),
                    _sponsorId,
                    _asset,
                    _threshold,
                    _nonce
                )
            )
        );
    }

    /// @notice Registers sponsorship
    /// @param _sponsorId - Id of the sponsor that should be set
    /// @param _asset - Asset that should be used for sponsoring
    /// @param _amount - Amount of asset that should be used for sponsoring
    function _registerSponsorship(bytes32 _sponsorId, address _asset, uint256 _amount) internal {
        Sponsor memory sponsor = sponsors[_sponsorId]; // Note! changes to memory value would not be reflected in storage

        if (sponsor.id == bytes32(0)) revert SponsorDoesNotExists(sponsor.id);
        if (sponsor.asset != _asset) revert InvalidAsset(sponsor.asset, _asset);

        sponsors[_sponsorId].payed += _amount;

        if (sponsor.fulfilledAt == 0 && sponsors[_sponsorId].payed >= sponsor.threshold) {
            sponsors[_sponsorId].fulfilledAt = block.timestamp;
            emit SponsorFulfilled(sponsor.id);
        }

        emit Sponsored(_sponsorId, _amount, sponsor.asset);
    }

    /// @notice Sets sponsor
    /// @param _sponsorId - Id of sponsor that should be set
    /// @param _asset - Asset that should be used for sponsoring
    /// @param _threshold - Threshold that should be used for sponsoring
    /// @param _signature - Operators signature with SponsorParams
    /// @dev if sponsor exists it will be reset
    function _setSponsor(bytes32 _sponsorId, address _asset, uint256 _threshold, uint32 _nonce, bytes calldata _signature) internal {
        if (_nonce <= sponsors[_sponsorId].nonce) revert NonceCollision(_nonce, sponsors[_sponsorId].nonce);
        sponsors[_sponsorId].nonce = _nonce;

        bytes32 digest = generateSponsorDigest(_sponsorId, _asset, _threshold, _nonce);

        _checkRole(OPERATOR_ROLE, ECDSA.recover(digest, _signature));

        sponsors[_sponsorId] = Sponsor(_sponsorId, _nonce, _asset, _threshold, 0, 0);

        emit SponsorReset(_sponsorId);
    }

    /// @notice Withdraws asset from contract
    /// @param _receiver - Address where asset should be sent
    /// @param _asset - Asset that should be withdrawn
    function _withdraw(address payable _receiver, Asset memory _asset) internal {
        if (_asset.assetAddress == address(0)) {
            _sendNativeToken(_receiver, _asset.amount);
        } else {
            _sendERC20Token(_asset.assetAddress, _receiver, _asset.amount);
        }

        emit Withdrawn(_receiver, _asset.assetAddress, _asset.amount);
    }

    /// @notice Sends native token to specified address
    /// @param _receiver - Address where native token should be sent
    /// @param _amount - Amount of native token that should be sent
    function _sendNativeToken(address payable _receiver, uint256 _amount) internal {
        (bool sent,) = _receiver.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice Sends ERC20 token to specified address
    /// @param _token - Address of ERC20 token
    /// @param _receiver - Address where ERC20 token should be sent
    /// @param _amount - Amount of ERC20 token that should be sent
    function _sendERC20Token(address _token, address _receiver, uint256 _amount) internal {
        IERC20(_token).safeTransfer(_receiver, _amount);
    }
}

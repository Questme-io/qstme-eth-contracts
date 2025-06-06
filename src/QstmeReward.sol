// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {EIP712Upgradeable} from "@openzeppelin-contracts-upgradeable-5.2.0/utils/cryptography/EIP712Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.2.0/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable-5.2.0/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin-contracts-5.2.0/utils/cryptography/ECDSA.sol";

import "./interfaces/IQstmeReward.sol";

contract QstmeReward is IQstmeReward, UUPSUpgradeable, AccessControlUpgradeable, EIP712Upgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    string public constant NAME = "QstmeReward";
    string public constant VERSION = "0.0.1";

    /// @notice recipient nonce
    mapping(address recepient => uint256 nonce) public recipientNonce;

    /// @notice controls that function could be called only by admin or operator
    modifier onlyAdminOrOperator() {
        if (!hasRole(OPERATOR_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotAnAdminOrOperator();
        }
        _;
    }

    function initialize(address _admin, address _operator) public initializer {
        __AccessControl_init();
        __EIP712_init(NAME, VERSION);
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _operator);
    }

    receive() external payable {}

    /// @inheritdoc IQstmeReward
    function getNonce(address _recipient) external view returns (uint256) {
        return recipientNonce[_recipient];
    }

    /// @inheritdoc IQstmeReward
    function receiveReward(
        address _recipient,
        address _asset,
        uint256 _amount,
        uint256 _nonce,
        bytes calldata _signature
    ) external {
        if (_nonce <= recipientNonce[_recipient]) revert NonceCollision(_nonce, recipientNonce[_recipient]);
        recipientNonce[_recipient] = _nonce;

        _validateRewardSignature(_recipient, _asset, _amount, _nonce, _signature);

        _sendReward(Reward(_recipient, _asset, _amount));
    }

    /// @inheritdoc IQstmeReward
    function reward(Reward calldata _reward) external onlyAdminOrOperator {
        _sendReward(_reward);
    }

    /// @inheritdoc IQstmeReward
    function rewardBatch(Reward[] calldata rewards) external onlyAdminOrOperator {
        for (uint256 i = 0; i < rewards.length; i++) {
            _sendReward(rewards[i]);
        }
    }

    /// @inheritdoc IQstmeReward
    function generateRewardDigest(address _recipient, address _asset, uint256 _amount, uint256 _nonce)
        public
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("RewardParams(address recipient,address asset,uint256 amount,uint256 nonce)"),
                    _recipient,
                    _asset,
                    _amount,
                    _nonce
                )
            )
        );
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(OPERATOR_ROLE) {}

    /// @notice Validates reward signature
    /// @param _recipient - address of the recipient
    /// @param _asset - asset that should be used for reward
    /// @param _amount - amount of the asset
    /// @param _nonce - updated recipient nonce
    /// @param _signature - operators signature with RewardParams
    function _validateRewardSignature(
        address _recipient,
        address _asset,
        uint256 _amount,
        uint256 _nonce,
        bytes calldata _signature
    ) internal view {
        bytes32 digest = generateRewardDigest(_recipient, _asset, _amount, _nonce);
        _checkRole(OPERATOR_ROLE, ECDSA.recover(digest, _signature));
    }

    /// @notice Parses and sends reward
    /// @param _reward - reward data to send
    function _sendReward(Reward memory _reward) internal {
        if (_reward.asset == address(0)) {
            _sendNativeToken(payable(_reward.recipient), _reward.amount);
        } else {
            _sendERC20Token(_reward.asset, _reward.recipient, _reward.amount);
        }
        recipientNonce[_reward.recipient] += 1;

        emit Rewarded(_reward.recipient, _reward.asset, _reward.amount);
    }

    /// @notice Sends native token to specified address
    /// @param _recipient - address where native token should be sent
    /// @param _amount - amount of native token that should be sent
    function _sendNativeToken(address payable _recipient, uint256 _amount) internal {
        (bool sent,) = _recipient.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice Sends ERC20 token to specified address
    /// @param _token - address of ERC20 token
    /// @param _recipient - address where ERC20 token should be sent
    /// @param _amount - amount of ERC20 token that should be sent
    function _sendERC20Token(address _token, address _recipient, uint256 _amount) internal {
        IERC20(_token).safeTransfer(_recipient, _amount);
    }
}

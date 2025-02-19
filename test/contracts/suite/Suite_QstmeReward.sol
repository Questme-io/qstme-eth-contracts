// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ECDSA} from "@openzeppelin-contracts-5.2.0/utils/cryptography/ECDSA.sol";
import {IAccessControl} from "@openzeppelin-contracts-5.2.0/access/IAccessControl.sol";
import {Strings} from "@openzeppelin-contracts-5.2.0/utils/Strings.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import "src/interfaces/IQstmeReward.sol";
import {IQstmeReward} from "test/contracts/harness/Harness_QstmeReward.sol";
import {Storage_QstmeReward} from "test/contracts/storage/Storage_QstmeReward.sol";

abstract contract Suite_QstmeReward is Storage_QstmeReward {
    using ECDSA for bytes32;

    mapping(address => mapping(address => uint256)) public sendAmounts;
    mapping(address => uint256)public sendNonces;

    function helper_sign(uint256 _privateKey, bytes32 _digest) public returns (bytes memory signature) {
        address signer = vm.addr(_privateKey);

        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, _digest);

        signature = abi.encodePacked(r, s, v);
        vm.stopPrank();
    }

    function expectUnauthorizedAccount(address _sender, bytes32 _role) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                _sender,
                _role
            )
        );
    }

    function test_receiveReward_Ok_NativeToken(
        address _recipient,
        uint256 _amount,
        uint32 _operatorPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_recipient);
        vm.assume(_amount > 0);
        deal(address(qstmeReward), _amount);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");

        (uint256 operatorPrivateKey, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeReward.helper_grantRole(OPERATOR_ROLE, operator);

        uint256 nonce = qstmeReward.recipientNonce(_recipient) + 1;

        bytes32 digest = qstmeReward.generateRewardDigest(_recipient, address(0), _amount, nonce);
        bytes memory signature = helper_sign(operatorPrivateKey, digest);

        uint256 balanceContractBefore = address(qstmeReward).balance;
        uint256 balanceRecipientBefore = _recipient.balance;

        vm.expectEmit();
        emit IQstmeReward.Rewarded(_recipient, address(0), _amount);

        vm.prank(sender);
        qstmeReward.receiveReward(
            _recipient,
            address(0),
            _amount,
            nonce,
            signature
        );

        assertEq(address(qstmeReward).balance, balanceContractBefore - _amount);
        assertEq(_recipient.balance, balanceRecipientBefore + _amount);
        assertEq(qstmeReward.recipientNonce(_recipient), nonce + 1);
    }

    function test_receiveReward_RevertIf_NonceCollision(
        address _recipient,
        uint256 _amount,
        uint32 _operatorPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_recipient);
        vm.assume(_amount > 0);
        deal(address(qstmeReward), _amount);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");

        (uint256 operatorPrivateKey, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeReward.helper_grantRole(OPERATOR_ROLE, operator);

        uint256 nonce = qstmeReward.recipientNonce(_recipient);

        bytes32 digest = qstmeReward.generateRewardDigest(_recipient, address(0), _amount, nonce);
        bytes memory signature = helper_sign(operatorPrivateKey, digest);

        uint256 balanceContractBefore = address(qstmeReward).balance;
        uint256 balanceRecipientBefore = _recipient.balance;

        vm.expectRevert(
            abi.encodeWithSelector(
                IQstmeReward.NonceCollision.selector,
                nonce,
                qstmeReward.recipientNonce(_recipient)
            )
        );
        vm.prank(sender);
        qstmeReward.receiveReward(
            _recipient,
            address(0),
            _amount,
            nonce,
            signature
        );

        assertEq(address(qstmeReward).balance, balanceContractBefore);
        assertEq(_recipient.balance, balanceRecipientBefore);
        assertEq(qstmeReward.recipientNonce(_recipient), nonce);
    }

    function test_receiveReward_RevertIf_SignatureIsInvalid(
        address _recipient,
        uint256 _amount,
        uint32 _operatorPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_recipient);
        vm.assume(_amount > 0);
        deal(address(qstmeReward), _amount);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");

        (uint256 operatorPrivateKey, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeReward.helper_grantRole(OPERATOR_ROLE, operator);

        uint256 nonce = qstmeReward.recipientNonce(_recipient);

        bytes32 digest = qstmeReward.generateRewardDigest(_recipient, address(0), _amount - 1, nonce + 1);
        bytes memory signature = helper_sign(operatorPrivateKey, digest);

        uint256 balanceContractBefore = address(qstmeReward).balance;
        uint256 balanceRecipientBefore = _recipient.balance;

        vm.expectRevert();
        vm.prank(sender);
        qstmeReward.receiveReward(
            _recipient,
            address(0),
            _amount,
            nonce + 1,
            signature
        );

        assertEq(address(qstmeReward).balance, balanceContractBefore);
        assertEq(_recipient.balance, balanceRecipientBefore);
        assertEq(qstmeReward.recipientNonce(_recipient), nonce);
    }

    function test_receiveReward_RevertIf_SignerIsNotAnOperator(
        address _recipient,
        uint256 _amount,
        uint32 _signerPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_recipient);
        vm.assume(_amount > 0);
        deal(address(qstmeReward), _amount);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");

        (uint256 signerPrivateKey, address signer) = generateAddress(_signerPrivateKeyIndex, "signer");

        uint256 nonce = qstmeReward.recipientNonce(_recipient);

        bytes32 digest = qstmeReward.generateRewardDigest(_recipient, address(0), _amount, nonce + 1);
        bytes memory signature = helper_sign(signerPrivateKey, digest);

        uint256 balanceContractBefore = address(qstmeReward).balance;
        uint256 balanceRecipientBefore = _recipient.balance;

        expectUnauthorizedAccount(signer, OPERATOR_ROLE);
        vm.prank(sender);
        qstmeReward.receiveReward(
            _recipient,
            address(0),
            _amount,
            nonce + 1,
            signature
        );

        assertEq(address(qstmeReward).balance, balanceContractBefore);
        assertEq(_recipient.balance, balanceRecipientBefore );
        assertEq(qstmeReward.recipientNonce(_recipient), nonce);
    }

    function test_reward_Ok_ERC20(
        Reward memory _reward,
        uint32 _operatorPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_reward.recipient);
        assumeUnusedAddress(_reward.asset);
        vm.assume(_reward.amount > 0);

        deployERC20(_reward.asset);
        deal(_reward.asset, address(qstmeReward), _reward.amount);

        (, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeReward.helper_grantRole(OPERATOR_ROLE, operator);

        uint256 balanceContractBefore = IERC20(_reward.asset).balanceOf(address(qstmeReward));
        uint256 balanceRecipientBefore = IERC20(_reward.asset).balanceOf(_reward.recipient);
        uint256 nonce = qstmeReward.recipientNonce(_reward.recipient);

        vm.expectEmit();
        emit IQstmeReward.Rewarded(_reward.recipient, _reward.asset, _reward.amount);

        vm.prank(operator);
        qstmeReward.reward(_reward);

        assertEq(IERC20(_reward.asset).balanceOf(address(qstmeReward)), balanceContractBefore - _reward.amount);
        assertEq(IERC20(_reward.asset).balanceOf(_reward.recipient), balanceRecipientBefore + _reward.amount);
        assertEq(qstmeReward.recipientNonce(_reward.recipient), nonce + 1);
    }

    function test_reward_RevertIf_NotAnOperator(
        Reward memory _reward,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_reward.recipient);
        assumeUnusedAddress(_reward.asset);
        vm.assume(_reward.amount > 0);

        deployERC20(_reward.asset);
        deal(_reward.asset, address(qstmeReward), _reward.amount);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");

        uint256 balanceContractBefore = IERC20(_reward.asset).balanceOf(address(qstmeReward));
        uint256 balanceRecipientBefore = IERC20(_reward.asset).balanceOf(_reward.recipient);
        uint256 nonce = qstmeReward.recipientNonce(_reward.recipient);

        vm.expectRevert(
            abi.encodeWithSelector(IQstmeReward.NotAnAdminOrOperator.selector)
        );
        vm.prank(sender);
        qstmeReward.reward(_reward);

        assertEq(IERC20(_reward.asset).balanceOf(address(qstmeReward)), balanceContractBefore);
        assertEq(IERC20(_reward.asset).balanceOf(_reward.recipient), balanceRecipientBefore);
        assertEq(qstmeReward.recipientNonce(_reward.recipient), nonce);
    }

    function test_rewardBatch_Ok(
        Reward[] memory _rewards,
        uint32 _operatorPrivateKeyIndex
    ) public {
        (, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeReward.helper_grantRole(OPERATOR_ROLE, operator);

        for (uint256 i = 0; i < _rewards.length; i++) {
            if (_rewards[i].asset != address(0)) {
                assumeUnusedAddress(_rewards[i].asset);
            }

            sendNonces[_rewards[i].recipient] += 1;
            sendAmounts[_rewards[i].recipient][_rewards[i].asset] += _rewards[i].amount;

            if (_rewards[i].asset == address(0)) {
                deal(address(qstmeReward), sendAmounts[_rewards[i].recipient][_rewards[i].asset]);
            } else {
                deployERC20(_rewards[i].asset);
                deal(_rewards[i].asset, address(qstmeReward), sendAmounts[_rewards[i].recipient][_rewards[i].asset]);
            }
        }

        uint256[] memory _recipientBalancesBefore = new uint256[](_rewards.length);
        uint256[] memory _recipientNoncesBefore = new uint256[](_rewards.length);
        uint256[] memory _contractBalancesBefore = new uint256[](_rewards.length);

        for (uint256 i = 0; i < _rewards.length; i++) {
            if (_rewards[i].asset == address(0)) {
                _recipientBalancesBefore[i] = _rewards[i].recipient.balance;
                _contractBalancesBefore[i] = address(qstmeReward).balance;
            } else {
                _recipientBalancesBefore[i] = IERC20(_rewards[i].asset).balanceOf(_rewards[i].recipient);
                _contractBalancesBefore[i] = IERC20(_rewards[i].asset).balanceOf(address(qstmeReward));
            }
            _recipientNoncesBefore[i] = qstmeReward.recipientNonce(_rewards[i].recipient);
        }

        for (uint256 i = 0; i < _rewards.length; i++) {
            if (
                _rewards[i].asset == address(0)
                || _rewards[i].asset > address(10)
            ) {
                vm.expectEmit();
                emit IQstmeReward.Rewarded(_rewards[i].recipient, _rewards[i].asset, _rewards[i].amount);
            }
        }

        vm.prank(operator);
        qstmeReward.rewardBatch(_rewards);

        for (uint256 i = 0; i < _rewards.length; i++) {
            if (_rewards[i].asset == address(0)) {
                assertEq(
                    _rewards[i].recipient.balance,
                    _recipientBalancesBefore[i] + _rewards[i].amount
                );

                assertEq(
                    address(qstmeReward).balance,
                    _contractBalancesBefore[i] - _rewards[i].amount
                );
            } else {
                assertEq(
                    IERC20(_rewards[i].asset).balanceOf(_rewards[i].recipient),
                    _recipientBalancesBefore[i] + _rewards[i].amount
                );

                assertEq(
                    IERC20(_rewards[i].asset).balanceOf(address(qstmeReward)),
                    _contractBalancesBefore[i] - _rewards[i].amount
                );
            }

            assertEq(
                qstmeReward.recipientNonce(_rewards[i].recipient),
                _recipientNoncesBefore[i] + sendNonces[_rewards[i].recipient]
            );
        }
    }

    function test_rewardBatch_RevertIf_NotAnOperator(
        Reward[] memory _rewards,
        uint32 _signerPrivateKeyIndex
    ) public {
        (, address signer) = generateAddress(_signerPrivateKeyIndex, "signer");

        for (uint256 i = 0; i < _rewards.length; i++) {
            if (_rewards[i].asset != address(0)) {
                assumeUnusedAddress(_rewards[i].asset);
            }

            sendNonces[_rewards[i].recipient] += 1;
            sendAmounts[_rewards[i].recipient][_rewards[i].asset] += _rewards[i].amount;

            if (_rewards[i].asset == address(0)) {
                deal(address(qstmeReward), sendAmounts[_rewards[i].recipient][_rewards[i].asset]);
            } else {
                deployERC20(_rewards[i].asset);
                deal(_rewards[i].asset, address(qstmeReward), sendAmounts[_rewards[i].recipient][_rewards[i].asset]);
            }
        }

        uint256[] memory _recipientBalancesBefore = new uint256[](_rewards.length);
        uint256[] memory _recipientNoncesBefore = new uint256[](_rewards.length);
        uint256[] memory _contractBalancesBefore = new uint256[](_rewards.length);

        for (uint256 i = 0; i < _rewards.length; i++) {
            if (_rewards[i].asset == address(0)) {
                _recipientBalancesBefore[i] = _rewards[i].recipient.balance;
                _contractBalancesBefore[i] = address(qstmeReward).balance;
            } else {
                _recipientBalancesBefore[i] = IERC20(_rewards[i].asset).balanceOf(_rewards[i].recipient);
                _contractBalancesBefore[i] = IERC20(_rewards[i].asset).balanceOf(address(qstmeReward));
            }
            _recipientNoncesBefore[i] = qstmeReward.recipientNonce(_rewards[i].recipient);
        }

        vm.expectRevert(
            abi.encodeWithSelector(IQstmeReward.NotAnAdminOrOperator.selector)
        );
        vm.prank(signer);
        qstmeReward.rewardBatch(_rewards);

        for (uint256 i = 0; i < _rewards.length; i++) {
            if (_rewards[i].asset == address(0)) {
                assertEq(
                    _rewards[i].recipient.balance,
                    _recipientBalancesBefore[i]
                );

                assertEq(
                    address(qstmeReward).balance,
                    _contractBalancesBefore[i]
                );
            } else {
                assertEq(
                    IERC20(_rewards[i].asset).balanceOf(_rewards[i].recipient),
                    _recipientBalancesBefore[i]
                );

                assertEq(
                    IERC20(_rewards[i].asset).balanceOf(address(qstmeReward)),
                    _contractBalancesBefore[i]
                );
            }

            assertEq(
                qstmeReward.recipientNonce(_rewards[i].recipient),
                _recipientNoncesBefore[i]
            );
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {ECDSA} from "@openzeppelin-contracts-5.2.0/utils/cryptography/ECDSA.sol";
import {IAccessControl} from "@openzeppelin-contracts-5.2.0/access/IAccessControl.sol";
import {Strings} from "@openzeppelin-contracts-5.2.0/utils/Strings.sol";
import {IERC20} from "@openzeppelin-contracts-5.2.0/token/ERC20/IERC20.sol";

import "src/interfaces/IQstmeSponsor.sol";
import {IQstmeSponsor} from "test/contracts/harness/Harness_QstmeSponsor.sol";
import {Storage_QstmeSponsor} from "test/contracts/storage/Storage_QstmeSponsor.sol";

abstract contract Suite_QstmeSponsor is Storage_QstmeSponsor {
    using ECDSA for bytes32;

    mapping(address => uint256) public withdrawAmounts;

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

    function test_Deployment() public view {
        assertTrue(qstmeSponsor.hasRole(DEFAULT_ADMIN_ROLE, address(this)));
        assertTrue(qstmeSponsor.hasRole(OPERATOR_ROLE, address(this)));
    }

    function test_getSponsor_Ok(Sponsor memory _sponsor) public {
        qstmeSponsor.helper_setSponsor(_sponsor);

        Sponsor memory sponsor = qstmeSponsor.getSponsor(bytes32(_sponsor.id));

        assertEq(sponsor.id, _sponsor.id);
        assertEq(sponsor.nonce, _sponsor.nonce);
        assertEq(sponsor.asset, _sponsor.asset);
        assertEq(sponsor.threshold, _sponsor.threshold);
        assertEq(sponsor.payed, _sponsor.payed);
        assertEq(sponsor.fulfilledAt, _sponsor.fulfilledAt);
    }

    function test_withdraw_Ok_ERC20asset(
        address _receiver,
        Asset memory _asset,
        uint32 _adminPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_receiver);
        assumeUnusedAddress(_asset.assetAddress);

        deployERC20(_asset.assetAddress);

        deal(_asset.assetAddress, address(qstmeSponsor), _asset.amount);
        (, address admin) = generateAddress(_adminPrivateKeyIndex, "admin");
        qstmeSponsor.helper_grantRole(DEFAULT_ADMIN_ROLE, admin);

        uint256 contractBalanceBefore = IERC20(_asset.assetAddress).balanceOf(address(qstmeSponsor));
        uint256 receiverBalanceBefore = IERC20(_asset.assetAddress).balanceOf(_receiver);

        vm.expectEmit();
        emit IQstmeSponsor.Withdrawn(_receiver, _asset.assetAddress, _asset.amount);

        vm.prank(admin);
        qstmeSponsor.withdraw(_receiver, _asset);

        uint256 contractBalanceAfter = IERC20(_asset.assetAddress).balanceOf(address(qstmeSponsor));
        uint256 receiverBalanceAfter = IERC20(_asset.assetAddress).balanceOf(_receiver);

        assertEq(contractBalanceAfter, contractBalanceBefore - _asset.amount);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + _asset.amount);
    }

    function test_withdraw_Ok_NativeAsset(
        address _receiver,
        Asset memory _asset,
        uint32 _adminPrivateKeyIndex
    ) public {
        vm.assume(_receiver != address(qstmeSponsor));
        assumePayable(_receiver);

        deal(address(qstmeSponsor), _asset.amount);
        (, address admin) = generateAddress(_adminPrivateKeyIndex, "admin");
        qstmeSponsor.helper_grantRole(DEFAULT_ADMIN_ROLE, admin);
        _asset.assetAddress = address(0);

        uint256 contractBalanceBefore = address(qstmeSponsor).balance;
        uint256 receiverBalanceBefore = address(_receiver).balance;

        vm.expectEmit();
        emit IQstmeSponsor.Withdrawn(_receiver, _asset.assetAddress, _asset.amount);

        vm.prank(admin);
        qstmeSponsor.withdraw(_receiver, _asset);

        uint256 contractBalanceAfter = address(qstmeSponsor).balance;
        uint256 receiverBalanceAfter = address(_receiver).balance;

        assertEq(contractBalanceAfter, contractBalanceBefore - _asset.amount);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + _asset.amount);
    }

    function test_withdraw_RevertIf_NotAnAdmin(
        address _receiver,
        Asset memory _asset,
        uint32 _anonymousPrivateKeyIndex
    ) public {
        vm.assume(_receiver != address(qstmeSponsor));
        assumePayable(_receiver);

        deal(address(qstmeSponsor), _asset.amount);
        (, address anonymousAddress) = generateAddress(_anonymousPrivateKeyIndex, "anonymous");
        _asset.assetAddress = address(0);

        uint256 contractBalanceBefore = address(qstmeSponsor).balance;
        uint256 receiverBalanceBefore = address(_receiver).balance;

        expectUnauthorizedAccount(anonymousAddress, DEFAULT_ADMIN_ROLE);
        vm.prank(anonymousAddress);
        qstmeSponsor.withdraw(_receiver, _asset);

        uint256 contractBalanceAfter = address(qstmeSponsor).balance;
        uint256 receiverBalanceAfter = address(_receiver).balance;

        assertEq(contractBalanceAfter, contractBalanceBefore);
        assertEq(receiverBalanceAfter, receiverBalanceBefore);
    }

    function test_withdrawBatch_Ok(
        address _receiver,
        Asset[] memory _assets,
        uint32 _adminPrivateKeyIndex
    ) public {
        vm.assume(_receiver != address(qstmeSponsor));
        assumeNotForgeAddress(_receiver);
        assumePayable(_receiver);

        (, address admin) = generateAddress(_adminPrivateKeyIndex, "admin");
        qstmeSponsor.helper_grantRole(DEFAULT_ADMIN_ROLE, admin);

        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i].assetAddress != address(0)) {
                assumeUnusedAddress(_assets[i].assetAddress);
            }

            withdrawAmounts[_assets[i].assetAddress] += _assets[i].amount;
            if (_assets[i].assetAddress == address(0)) {
                deal(address(qstmeSponsor), withdrawAmounts[_assets[i].assetAddress]);
            } else {
                deployERC20(_assets[i].assetAddress);
                deal(_assets[i].assetAddress, address(qstmeSponsor), withdrawAmounts[_assets[i].assetAddress]);
            }
        }

        uint256[] memory _receiverBalancesBefore = new uint256[](_assets.length);
        uint256[] memory _contractBalancesBefore = new uint256[](_assets.length);

        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i].assetAddress == address(0)) {
                _receiverBalancesBefore[i] = _receiver.balance;
                _contractBalancesBefore[i] = address(qstmeSponsor).balance;
            } else {
                _receiverBalancesBefore[i] = IERC20(_assets[i].assetAddress).balanceOf(_receiver);
                _contractBalancesBefore[i] = IERC20(_assets[i].assetAddress).balanceOf(address(qstmeSponsor));
            }
        }

        for (uint256 i = 0; i < _assets.length; i++) {
            if (
                _assets[i].assetAddress == address(0)
                || _assets[i].assetAddress > address(10)
            ) {
                vm.expectEmit();
                emit IQstmeSponsor.Withdrawn(_receiver, _assets[i].assetAddress, _assets[i].amount);
            }
        }

        vm.prank(admin);
        qstmeSponsor.withdrawBatch(_receiver, _assets);

        for (uint256 i = 0; i < _assets.length; i++) {
            if (_assets[i].assetAddress == address(0)) {
                assertEq(
                    _receiver.balance,
                    _receiverBalancesBefore[i] + withdrawAmounts[_assets[i].assetAddress]
                );

                assertEq(
                    address(qstmeSponsor).balance,
                    _contractBalancesBefore[i] - withdrawAmounts[_assets[i].assetAddress]
                );
            } else {
                assertEq(
                    IERC20(_assets[i].assetAddress).balanceOf(_receiver),
                    _receiverBalancesBefore[i] + withdrawAmounts[_assets[i].assetAddress]
                );

                assertEq(
                    IERC20(_assets[i].assetAddress).balanceOf(address(qstmeSponsor)),
                    _contractBalancesBefore[i] - withdrawAmounts[_assets[i].assetAddress]
                );
            }
        }
    }

    function test_withdrawBatch_RevertIf_NotAnAdmin(
        address _receiver,
        Asset[] memory _assets,
        uint32 _anonymousPrivateKeyIndex
    ) public {
        vm.assume(_receiver != address(qstmeSponsor));
        assumeNotForgeAddress(_receiver);
        assumePayable(_receiver);

        (, address anonymousAddress) = generateAddress(_anonymousPrivateKeyIndex, "anonymousAddress");

        expectUnauthorizedAccount(anonymousAddress, DEFAULT_ADMIN_ROLE);
        vm.prank(anonymousAddress);
        qstmeSponsor.withdrawBatch(_receiver, _assets);
    }

    function test_resetAndSendSponsorship_Ok_NativeToken_EnoughAmount(
        bytes32 _sponsorId,
        uint256 _amount,
        uint256 _threshold,
        uint32 _operatorPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        vm.assume(_sponsorId != bytes32(0));

        uint256 amount = bound(_amount, _threshold, type(uint256).max);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");
        deal(sender, amount);

        (uint256 operatorPrivateKey, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeSponsor.helper_grantRole(OPERATOR_ROLE, operator);

        uint32 nonce = qstmeSponsor.getSponsor(_sponsorId).nonce + 1;

        bytes32 digest = qstmeSponsor.generateSponsorDigest(_sponsorId, address(0), _threshold, nonce);
        bytes memory signature = helper_sign(operatorPrivateKey, digest);

        uint256 balanceContractBefore = address(qstmeSponsor).balance;
        uint256 balanceSenderBefore = sender.balance;

        vm.expectEmit();
        emit IQstmeSponsor.SponsorReset(_sponsorId);

        vm.expectEmit();
        emit IQstmeSponsor.SponsorFulfilled(_sponsorId);

        vm.expectEmit();
        emit IQstmeSponsor.Sponsored(_sponsorId, amount, address(0));

        vm.prank(sender);
        qstmeSponsor.resetAndSendSponsorship{value: amount}(
            _sponsorId,
            address(0),
            amount,
            _threshold,
            nonce,
            signature
        );

        Sponsor memory sponsor = qstmeSponsor.getSponsor(_sponsorId);

        assertEq(sponsor.nonce, nonce);
        assertEq(sponsor.id, _sponsorId);
        assertEq(sponsor.asset, address(0));
        assertEq(sponsor.threshold, _threshold);
        assertEq(sponsor.payed, amount);
        assertEq(sponsor.fulfilledAt, block.timestamp);

        assertEq(address(qstmeSponsor).balance, balanceContractBefore + amount);
        assertEq(sender.balance, balanceSenderBefore - amount);
    }

    function test_resetAndSendSponsorship_Ok_NativeToken_NotEnoughAmount(
        bytes32 _sponsorId,
        uint256 _amount,
        uint256 _threshold,
        uint32 _operatorPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        vm.assume(_amount < _threshold);
        vm.assume(_sponsorId != bytes32(0));

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");
        deal(sender, _amount);

        (uint256 operatorPrivateKey, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeSponsor.helper_grantRole(OPERATOR_ROLE, operator);

        uint32 nonce = qstmeSponsor.getSponsor(_sponsorId).nonce + 1;

        bytes32 digest = qstmeSponsor.generateSponsorDigest(_sponsorId, address(0), _threshold, nonce);
        bytes memory signature = helper_sign(operatorPrivateKey, digest);

        uint256 balanceContractBefore = address(qstmeSponsor).balance;
        uint256 balanceSenderBefore = sender.balance;

        vm.expectEmit();
        emit IQstmeSponsor.SponsorReset(_sponsorId);

        vm.expectEmit();
        emit IQstmeSponsor.Sponsored(_sponsorId, _amount, address(0));

        vm.prank(sender);
        qstmeSponsor.resetAndSendSponsorship{value: _amount}(
            _sponsorId,
            address(0),
            _amount,
            _threshold,
            nonce,
            signature
        );

        Sponsor memory sponsor = qstmeSponsor.getSponsor(_sponsorId);

        assertEq(sponsor.nonce, nonce);
        assertEq(sponsor.id, _sponsorId);
        assertEq(sponsor.asset, address(0));
        assertEq(sponsor.threshold, _threshold);
        assertEq(sponsor.payed, _amount);
        assertEq(sponsor.fulfilledAt, 0);

        assertEq(address(qstmeSponsor).balance, balanceContractBefore + _amount);
        assertEq(sender.balance, balanceSenderBefore - _amount);
    }

    function test_resetAndSendSponsorship_Ok_ERC20_EnoughAmount(
        bytes32 _sponsorId,
        address _asset,
        uint256 _amount,
        uint256 _threshold,
        uint32 _operatorPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_asset);
        vm.assume(_sponsorId != bytes32(0));
        vm.assume(_amount >= _threshold);

        deployERC20(_asset);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");
        deal(_asset, sender, _amount);

        vm.prank(sender);
        IERC20(_asset).approve(address(qstmeSponsor), _amount);

        (uint256 operatorPrivateKey, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeSponsor.helper_grantRole(OPERATOR_ROLE, operator);

        uint32 nonce = qstmeSponsor.getSponsor(_sponsorId).nonce + 1;

        bytes32 digest = qstmeSponsor.generateSponsorDigest(_sponsorId, _asset, _threshold, nonce);
        bytes memory signature = helper_sign(operatorPrivateKey, digest);

        uint256 balanceContractBefore = IERC20(_asset).balanceOf(address(qstmeSponsor));
        uint256 balanceSenderBefore = IERC20(_asset).balanceOf(sender);

        vm.expectEmit();
        emit IQstmeSponsor.SponsorReset(_sponsorId);

        vm.expectEmit();
        emit IQstmeSponsor.SponsorFulfilled(_sponsorId);

        vm.expectEmit();
        emit IQstmeSponsor.Sponsored(_sponsorId, _amount, _asset);

        vm.prank(sender);
        qstmeSponsor.resetAndSendSponsorship(
            _sponsorId,
            _asset,
            _amount,
            _threshold,
            nonce,
            signature
        );

        Sponsor memory sponsor = qstmeSponsor.getSponsor(_sponsorId);

        assertEq(sponsor.nonce, nonce);
        assertEq(sponsor.id, _sponsorId);
        assertEq(sponsor.asset, _asset);
        assertEq(sponsor.threshold, _threshold);
        assertEq(sponsor.payed, _amount);
        assertEq(sponsor.fulfilledAt, block.timestamp);

        assertEq(IERC20(_asset).balanceOf(address(qstmeSponsor)), balanceContractBefore + _amount);
        assertEq(IERC20(_asset).balanceOf(sender), balanceSenderBefore - _amount);
    }

    function test_resetAndSendSponsorship_Ok_ERC20_NotEnoughAmount(
        bytes32 _sponsorId,
        address _asset,
        uint256 _amount,
        uint256 _threshold,
        uint32 _operatorPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_asset);
        vm.assume(_sponsorId != bytes32(0));
        vm.assume(_amount < _threshold);

        deployERC20(_asset);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");
        deal(_asset, sender, _amount);

        vm.prank(sender);
        IERC20(_asset).approve(address(qstmeSponsor), _amount);

        (uint256 operatorPrivateKey, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeSponsor.helper_grantRole(OPERATOR_ROLE, operator);

        uint32 nonce = qstmeSponsor.getSponsor(_sponsorId).nonce + 1;

        bytes32 digest = qstmeSponsor.generateSponsorDigest(_sponsorId, _asset, _threshold, nonce);
        bytes memory signature = helper_sign(operatorPrivateKey, digest);

        uint256 balanceContractBefore = IERC20(_asset).balanceOf(address(qstmeSponsor));
        uint256 balanceSenderBefore = IERC20(_asset).balanceOf(sender);

        vm.expectEmit();
        emit IQstmeSponsor.SponsorReset(_sponsorId);

        vm.expectEmit();
        emit IQstmeSponsor.Sponsored(_sponsorId, _amount, _asset);

        vm.prank(sender);
        qstmeSponsor.resetAndSendSponsorship(
            _sponsorId,
            _asset,
            _amount,
            _threshold,
            nonce,
            signature
        );

        Sponsor memory sponsor = qstmeSponsor.getSponsor(_sponsorId);

        assertEq(sponsor.nonce, nonce);
        assertEq(sponsor.id, _sponsorId);
        assertEq(sponsor.asset, _asset);
        assertEq(sponsor.threshold, _threshold);
        assertEq(sponsor.payed, _amount);
        assertEq(sponsor.fulfilledAt, 0);

        assertEq(IERC20(_asset).balanceOf(address(qstmeSponsor)), balanceContractBefore + _amount);
        assertEq(IERC20(_asset).balanceOf(sender), balanceSenderBefore - _amount);
    }

    function test_resetAndSendSponsorship_RevertIf_SignerIsNotAnOperator(
        bytes32 _sponsorId,
        address _asset,
        uint256 _amount,
        uint256 _threshold,
        uint32 _signerPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_asset);
        vm.assume(_sponsorId != bytes32(0));
        vm.assume(_amount < _threshold);

        deployERC20(_asset);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");
        deal(_asset, sender, _amount);

        vm.prank(sender);
        IERC20(_asset).approve(address(qstmeSponsor), _amount);

        (uint256 signerPrivateKey, address signer) = generateAddress(_signerPrivateKeyIndex, "signer");

        uint32 nonce = qstmeSponsor.getSponsor(_sponsorId).nonce + 1;

        bytes32 digest = qstmeSponsor.generateSponsorDigest(_sponsorId, _asset, _threshold, nonce);
        bytes memory signature = helper_sign(signerPrivateKey, digest);

        uint256 balanceContractBefore = IERC20(_asset).balanceOf(address(qstmeSponsor));
        uint256 balanceSenderBefore = IERC20(_asset).balanceOf(sender);

        expectUnauthorizedAccount(signer, OPERATOR_ROLE);
        vm.prank(sender);
        qstmeSponsor.resetAndSendSponsorship(
            _sponsorId,
            _asset,
            _amount,
            _threshold,
            nonce,
            signature
        );

        assertEq(IERC20(_asset).balanceOf(address(qstmeSponsor)), balanceContractBefore);
        assertEq(IERC20(_asset).balanceOf(sender), balanceSenderBefore);
    }

    function test_resetAndSendSponsorship_RevertIf_SignatureIsInvalid(
        bytes32 _sponsorId,
        address _asset,
        uint256 _amount,
        uint256 _threshold,
        uint32 _operatorPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_asset);
        vm.assume(_sponsorId != bytes32(0));
        vm.assume(_threshold > 0);
        vm.assume(_amount < _threshold);

        deployERC20(_asset);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");
        deal(_asset, sender, _amount);

        vm.prank(sender);
        IERC20(_asset).approve(address(qstmeSponsor), _amount);

        (uint256 operatorPrivateKey, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeSponsor.helper_grantRole(OPERATOR_ROLE, operator);

        uint32 nonce = qstmeSponsor.getSponsor(_sponsorId).nonce + 1;

        bytes32 digest = qstmeSponsor.generateSponsorDigest(_sponsorId, _asset, _threshold - 1, nonce);
        bytes memory signature = helper_sign(operatorPrivateKey, digest);

        uint256 balanceContractBefore = IERC20(_asset).balanceOf(address(qstmeSponsor));
        uint256 balanceSenderBefore = IERC20(_asset).balanceOf(sender);

        vm.expectRevert();
        vm.prank(sender);
        qstmeSponsor.resetAndSendSponsorship(
            _sponsorId,
            _asset,
            _amount,
            _threshold,
            nonce,
            signature
        );

        assertEq(IERC20(_asset).balanceOf(address(qstmeSponsor)), balanceContractBefore);
        assertEq(IERC20(_asset).balanceOf(sender), balanceSenderBefore);
    }

    function test_resetAndSendSponsorship_RevertIf_NotEnoughAllowance(
        bytes32 _sponsorId,
        address _asset,
        uint256 _amount,
        uint256 _threshold,
        uint32 _operatorPrivateKeyIndex,
        uint32 _senderPrivateKeyIndex
    ) public {
        assumeUnusedAddress(_asset);
        vm.assume(_sponsorId != bytes32(0));
        vm.assume(_threshold > 0);
        vm.assume(_amount > 0);
        vm.assume(_amount < _threshold);

        deployERC20(_asset);

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");
        deal(_asset, sender, _amount);

        (uint256 operatorPrivateKey, address operator) = generateAddress(_operatorPrivateKeyIndex, "operator");
        qstmeSponsor.helper_grantRole(OPERATOR_ROLE, operator);

        uint32 nonce = qstmeSponsor.getSponsor(_sponsorId).nonce + 1;

        bytes32 digest = qstmeSponsor.generateSponsorDigest(_sponsorId, _asset, _threshold, nonce);
        bytes memory signature = helper_sign(operatorPrivateKey, digest);

        uint256 balanceContractBefore = IERC20(_asset).balanceOf(address(qstmeSponsor));
        uint256 balanceSenderBefore = IERC20(_asset).balanceOf(sender);

        vm.expectRevert(
            abi.encodeWithSelector(
                IQstmeSponsor.NotEnoughAllowance.selector,
                IERC20(_asset).allowance(sender, address(qstmeSponsor)),
                _amount
            )
        );
        vm.prank(sender);
        qstmeSponsor.resetAndSendSponsorship(
            _sponsorId,
            _asset,
            _amount,
            _threshold,
            nonce,
            signature
        );

        assertEq(IERC20(_asset).balanceOf(address(qstmeSponsor)), balanceContractBefore);
        assertEq(IERC20(_asset).balanceOf(sender), balanceSenderBefore);
    }

    function test_sendSponsorship_Ok_NativeToken_EnoughAmount(
        bytes32 _sponsorId,
        uint256 _amount,
        uint256 _threshold,
        uint32 _senderPrivateKeyIndex
    ) public {
        vm.assume(_sponsorId != bytes32(0));
        vm.assume(_amount > _threshold);

        qstmeSponsor.helper_setSponsor(Sponsor(_sponsorId, 0, address(0), _threshold, 0, 0));

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");
        deal(sender, _amount);

        uint256 balanceContractBefore = address(qstmeSponsor).balance;
        uint256 balanceSenderBefore = sender.balance;

        vm.expectEmit();
        emit IQstmeSponsor.SponsorFulfilled(_sponsorId);

        vm.expectEmit();
        emit IQstmeSponsor.Sponsored(_sponsorId, _amount, address(0));

        vm.prank(sender);
        qstmeSponsor.sendSponsorship{value: _amount}(
            _sponsorId,
            address(0),
            _amount
        );

        Sponsor memory sponsor = qstmeSponsor.getSponsor(_sponsorId);

        assertEq(sponsor.id, _sponsorId);
        assertEq(sponsor.payed, _amount);
        assertEq(sponsor.fulfilledAt, block.timestamp);

        assertEq(address(qstmeSponsor).balance, balanceContractBefore + _amount);
        assertEq(sender.balance, balanceSenderBefore - _amount);
    }

    function test_sendSponsorship_Ok_NativeToken_NotEnoughAmount(
        bytes32 _sponsorId,
        uint256 _amount,
        uint256 _threshold,
        uint32 _senderPrivateKeyIndex
    ) public {
        vm.assume(_amount < _threshold);
        vm.assume(_sponsorId != bytes32(0));

        qstmeSponsor.helper_setSponsor(Sponsor(_sponsorId, 0, address(0), _threshold, 0, 0));

        (, address sender) = generateAddress(_senderPrivateKeyIndex, "sender");
        deal(sender, _amount);

        uint256 balanceContractBefore = address(qstmeSponsor).balance;
        uint256 balanceSenderBefore = sender.balance;

        vm.expectEmit();
        emit IQstmeSponsor.Sponsored(_sponsorId, _amount, address(0));

        vm.prank(sender);
        qstmeSponsor.sendSponsorship{value: _amount}(
            _sponsorId,
            address(0),
            _amount
        );

        Sponsor memory sponsor = qstmeSponsor.getSponsor(_sponsorId);

        assertEq(sponsor.id, _sponsorId);
        assertEq(sponsor.payed, _amount);
        assertEq(sponsor.fulfilledAt, 0);

        assertEq(address(qstmeSponsor).balance, balanceContractBefore + _amount);
        assertEq(sender.balance, balanceSenderBefore - _amount);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/interfaces/IQstmeReward.sol";
import {QstmeReward} from "src/QstmeReward.sol";

contract Harness_QstmeReward is QstmeReward {
    constructor(address _admin, address _operator) QstmeReward(_admin, _operator) {}

    function exposed_validateRewardSignature(address _recipient, address _asset, uint256 _amount, uint32 _nonce, bytes calldata _signature) view public {
        _validateRewardSignature(_recipient, _asset, _amount, _nonce, _signature);
    }

    function exposed_sendReward(address payable _recipient, address _asset, uint256 _amount) public {
        _sendReward(Reward(_recipient, _asset, _amount));
    }

    function exposed_sendNativeToken(address payable _recipient, uint256 _amount) public {
        _sendNativeToken(_recipient, _amount);
    }

    function exposed_sendERC20Token(address _token, address _recipient, uint256 _amount) public {
        _sendERC20Token(_token, _recipient, _amount);
    }

    function helper_grantRole(bytes32 _role, address _account) public {
        _grantRole(_role, _account);
    }

    function helper_revokeRole(bytes32 _role, address _account) public {
        _revokeRole(_role, _account);
    }
}

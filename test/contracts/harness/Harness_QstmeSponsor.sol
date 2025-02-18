// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "src/interfaces/IQstmeSponsor.sol";
import {QstmeSponsor} from "src/QstmeSponsor.sol";

contract Harness_QstmeSponsor is QstmeSponsor {
    constructor(address _admin, address _operator) QstmeSponsor(_admin, _operator) {}

    function exposed_registerSponsorship(bytes32 _sponsorId, address _asset, uint256 _amount) public {
        _registerSponsorship(_sponsorId, _asset, _amount);
    }

    function exposed_setSponsor(bytes32 _sponsorId, address _asset, uint256 _threshold, uint32 _nonce, bytes calldata _signature) public {
        _setSponsor(_sponsorId, _asset, _threshold, _nonce, _signature);
    }

    function exposed_withdraw(address payable _receiver, Asset memory _asset) public {
        _withdraw(_receiver, _asset);
    }

    function exposed_sendNativeToken(address payable _receiver, uint256 _amount) public {
        _sendNativeToken(_receiver, _amount);
    }

    function exposed_sendERC20Token(address _token, address _receiver, uint256 _amount) public {
        _sendERC20Token(_token, _receiver, _amount);
    }

    function helper_setSponsor(Sponsor memory _sponsor) public {
        sponsors[_sponsor.id] = _sponsor;
    }

    function helper_grantRole(bytes32 _role, address _account) public {
        _grantRole(_role, _account);
    }

    function helper_revokeRole(bytes32 _role, address _account) public {
        _revokeRole(_role, _account);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Harness_QstmeSponsor} from "test/contracts/harness/Harness_QstmeSponsor.sol";
import {Storage_QstmeSponsor} from "test/contracts/storage/Storage_QstmeSponsor.sol";

abstract contract Environment_QstmeSponsor is Storage_QstmeSponsor {
    function _prepareEnv() internal override {
        qstmeSponsor = new Harness_QstmeSponsor();
        qstmeSponsor.initialize(address(this), address(this));
    }
}

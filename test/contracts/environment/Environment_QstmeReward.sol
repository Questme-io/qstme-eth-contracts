// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Harness_QstmeReward} from "test/contracts/harness/Harness_QstmeReward.sol";
import {Storage_QstmeReward} from "test/contracts/storage/Storage_QstmeReward.sol";

abstract contract Environment_QstmeReward is Storage_QstmeReward {
    function _prepareEnv() internal override {
        qstmeReward = new Harness_QstmeReward(address(this), address(this));
    }
}

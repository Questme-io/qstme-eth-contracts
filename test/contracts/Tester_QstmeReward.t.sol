// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Suite_QstmeReward} from "./suite/Suite_QstmeReward.sol";
import {Environment_QstmeReward} from "./environment/Environment_QstmeReward.sol";

contract Tester_QstmeReward is
    Environment_QstmeReward,
    Suite_QstmeReward
    {}

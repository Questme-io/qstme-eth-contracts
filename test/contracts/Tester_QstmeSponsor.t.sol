// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Suite_QstmeSponsor} from "./suite/Suite_QstmeSponsor.sol";
import {Environment_QstmeSponsor} from "./environment/Environment_QstmeSponsor.sol";

contract Tester_QstmeSponsor is Environment_QstmeSponsor, Suite_QstmeSponsor {}

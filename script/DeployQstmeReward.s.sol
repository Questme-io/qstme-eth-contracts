// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "lib/forge-std/src/Script.sol";

import {QstmeReward} from "../src/QstmeReward.sol";

contract DeployQstmeRewardScript is Script {
    function run(string calldata network) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        _run(network, deployerPrivateKey);
    }

    function _run(string calldata network, uint256 deployerPrivateKey) internal {
        vm.createSelectFork(network);

        address deployer = vm.addr(deployerPrivateKey);

        vm.broadcast(deployerPrivateKey);
        QstmeReward qstMeSponsor = new QstmeReward(
            deployer,
            0x381c031bAA5995D0Cc52386508050Ac947780815
        );

        console.log("QstmeReward contract deployed at: ", address(qstMeSponsor));
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "lib/forge-std/src/Script.sol";

import {QstmeSponsor} from "src/QstmeSponsor.sol";

contract DeployQstmeSponsorScript is Script {
    function run(string calldata network) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        _run(network, deployerPrivateKey);
    }

    function _run(string calldata network, uint256 deployerPrivateKey) internal {
        vm.createSelectFork(network);

        address deployer = vm.addr(deployerPrivateKey);

        vm.broadcast(deployerPrivateKey);
        QstmeSponsor qstMeSponsor = new QstmeSponsor(
            deployer,
            0x381c031bAA5995D0Cc52386508050Ac947780815
        );

        console.log("Sponsor contract deployed at: ", address(qstMeSponsor));
    }
}
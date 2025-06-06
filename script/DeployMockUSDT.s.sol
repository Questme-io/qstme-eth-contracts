// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "lib/forge-std/src/Script.sol";

import {QstmeSponsor} from "src/QstmeSponsor.sol";
import {Mock_USDT} from "src/mock/Mock_USDT.sol";

contract DeployMockUSDTScript is Script {
    function run(string calldata network) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        _run(network, deployerPrivateKey);
    }

    function _run(string calldata network, uint256 deployerPrivateKey) internal {
        vm.createSelectFork(network);

        require(
            block.chainid == 11155420 // optimismSepolia
                || block.chainid == 84532, // baseSepolia
            "Only testnets"
        );

        address deployer = vm.addr(deployerPrivateKey);

        vm.broadcast(deployerPrivateKey);
        Mock_USDT qstMeSponsor = new Mock_USDT();

        console.log("Sponsor contract deployed at: ", address(qstMeSponsor));
    }
}

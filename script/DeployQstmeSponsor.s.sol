// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "lib/forge-std/src/Script.sol";
import {SafeSingletonDeployer} from "./helpers/SafeSingletonDeployer.sol";
import {ERC1967Proxy} from "@openzeppelin-contracts-5.2.0/proxy/ERC1967/ERC1967Proxy.sol";

import {QstmeSponsor} from "src/QstmeSponsor.sol";

contract DeployQstmeSponsorScript is Script {
    address public constant ADMIN = 0x885CefFc2f5428C3A2C5895204335ED6dcf466a1;
    address public constant OPERATOR = 0x91430EC444FD8249e152aDf82a73f985b031276E;

    function run(string calldata network) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        bytes32 salt = keccak256("QstmeSponsor");

        _run(network, deployerPrivateKey, salt);
    }

    function _run(string calldata network, uint256 deployerPrivateKey, bytes32 salt) internal {
        vm.createSelectFork(network);

        address deployer = vm.addr(deployerPrivateKey);

        address qstmeSponsor = SafeSingletonDeployer.broadcastDeploy({
            deployerPrivateKey: deployerPrivateKey,
            creationCode: type(QstmeSponsor).creationCode,
            args: "",
            salt: salt
        });

        address proxy = SafeSingletonDeployer.broadcastDeploy({
            deployerPrivateKey: deployerPrivateKey,
            creationCode: type(ERC1967Proxy).creationCode,
            args: abi.encode(address(qstmeSponsor), ""),
            salt: salt
        });

        vm.broadcast(deployerPrivateKey);
        QstmeSponsor(proxy).initialize(ADMIN, OPERATOR);
    }
}

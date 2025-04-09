// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "lib/forge-std/src/Script.sol";

import {Sponsor} from "../src/interfaces/IQstmeSponsor.sol";
import {QstmeSponsor} from "../src/QstmeSponsor.sol";

contract SendSponsorshipScript is Script {
    bytes32 public constant sponsorId = 0x93d6461305ef70646cd0e5661b4dda939249c7b9e7d4ec4acc367b226b227836;
    address public constant asset = address(0);
    uint256 public constant amount = 200;

    mapping(string => address) public chains;

    function run(string calldata network) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        chains["optimismSepolia"] = 0x51b188526c48169e1f12e9a83623f3ee215a740b;

        _run(network, deployerPrivateKey);
    }

    function _run(string calldata network, uint256 deployerPrivateKey) internal {
        vm.createSelectFork(network);
        require(chains[network] != address(0), "Onchain address is ZERO");

        address deployer = vm.addr(deployerPrivateKey);

        QstmeSponsor qstMeSponsor = QstmeSponsor(chains[network]);

        Sponsor memory sponsor = qstMeSponsor.getSponsor(sponsorId);

        uint256 value = 0;

        if (asset == address(0)) {
            value = amount;
        }

        vm.broadcast(deployerPrivateKey);
        qstMeSponsor.sendSponsorship{ value: value }(sponsorId, asset, amount);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "lib/forge-std/src/Script.sol";

import {Sponsor} from "../src/interfaces/IQstmeSponsor.sol";
import {QstmeSponsor} from "../src/QstmeSponsor.sol";

contract ResetAndSponsorScript is Script {
    bytes32 public constant sponsorId = keccak256("sponsor_1");
    address public constant asset = address(0);
    uint256 public constant amount = 100;
    uint256 public constant threshold = 300;

    mapping(string => address) public chains;

    function helper_sign(uint256 _privateKey, bytes32 _digest) public returns (bytes memory signature) {
        address signer = vm.addr(_privateKey);

        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, _digest);

        signature = abi.encodePacked(r, s, v);
        vm.stopPrank();
    }

    function run(string calldata network) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        chains["baseSepolia"] = 0x51b188526c48169e1f12e9a83623f3ee215a740b;

        _run(network, deployerPrivateKey);
    }

    function _run(string calldata network, uint256 deployerPrivateKey) internal {
        vm.createSelectFork(network);
        require(chains[network] != address(0), "Onchain address is ZERO");

        address deployer = vm.addr(deployerPrivateKey);

        QstmeSponsor qstMeSponsor = QstmeSponsor(chains[network]);

        Sponsor memory sponsor = qstMeSponsor.getSponsor(sponsorId);

        uint32 nonce = sponsor.nonce + 1;

        bytes32 digest = qstMeSponsor.generateSponsorDigest(sponsorId, asset, threshold, nonce);

        bytes memory signature = helper_sign(deployerPrivateKey, digest);

        uint256 value = 0;

        if (asset == address(0)) {
            value = amount;
        }

        vm.broadcast(deployerPrivateKey);
        qstMeSponsor.resetAndSendSponsorship{ value: value }(sponsorId, asset, amount, threshold, nonce, signature);
    }
}
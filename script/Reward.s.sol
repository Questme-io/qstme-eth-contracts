// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "lib/forge-std/src/Script.sol";

import {Reward} from "../src/interfaces/IQstmeReward.sol";
import {QstmeReward} from "../src/QstmeReward.sol";

contract RewardScript is Script {
    address public constant asset = address(0);
    uint256 public constant amount = 100;

    mapping(string => address) public chains;

    function helper_sign(uint256 _privateKey, bytes32 _digest) public returns (bytes memory signature) {
        address signer = vm.addr(_privateKey);

        vm.startPrank(signer);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, _digest);

        signature = abi.encodePacked(r, s, v);
        vm.stopPrank();
    }

    function run(string calldata network, address recipient) external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        chains["optimismSepolia"] = 0x6B08093d7C1F3c216e830A01B793461764df92b4;

        _run(network, deployerPrivateKey, recipient);
    }

    function _run(string calldata network, uint256 deployerPrivateKey, address recipient) internal {
        vm.createSelectFork(network);
        require(chains[network] != address(0), "Onchain address is ZERO");

        QstmeReward qstMeReward = QstmeReward(payable(chains[network]));

        Reward memory reward = Reward(recipient, asset, amount);

        vm.broadcast(deployerPrivateKey);
        qstMeReward.reward(reward);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import { Script } from "../lib/forge-std/src/Script.sol";

import { Register } from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import { IRouterClient } from "../lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Client } from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";


contract BridgeTokens is Script {
    function run(address user, address localToken, uint256 amountBridge, Register.NetworkDetails memory localNetwork, Register.NetworkDetails memory remoteNetwork) public {
        vm.startBroadcast(user);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountBridge
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetwork.linkAddress,
            extraArgs: ""
        });

        uint256 fee = IRouterClient(localNetwork.routerAddress).getFee(remoteNetwork.chainSelector, message);

        IERC20(localNetwork.linkAddress).approve(localNetwork.routerAddress, fee);
        IERC20(localToken).approve(localNetwork.routerAddress, amountBridge);

        IRouterClient(localNetwork.routerAddress).ccipSend(remoteNetwork.chainSelector, message);

        vm.stopBroadcast();
    }

}
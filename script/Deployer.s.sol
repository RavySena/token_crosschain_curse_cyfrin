// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import { Script } from "../lib/forge-std/src/Script.sol";

import { RebaseToken } from "../src/RebaseToken.sol";
import { Vault } from "../src/Vault.sol";
import { RebaseTokenPool } from "../src/RebaseTokenPool.sol";

import { CCIPLocalSimulatorFork, Register } from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import { RegistryModuleOwnerCustom } from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import { TokenAdminRegistry } from "../lib/ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";


contract TokenAndPoolDeployer is Script {
    function run(address owner, address rmnProxyAddress, address routerAddress, address registryModuleOwnerCustomAddress, address tokenAdminRegistryAddress) public returns (RebaseToken rebaseToken, RebaseTokenPool pool) {
        vm.startBroadcast(owner);

        rebaseToken = new RebaseToken();

        if (rmnProxyAddress != address(0)) {
            pool = new RebaseTokenPool(address(rebaseToken), new address[](0), rmnProxyAddress, routerAddress);
            rebaseToken.addBurningAndMintingPermission(address(pool));

            registry(address(rebaseToken), address(pool), registryModuleOwnerCustomAddress, tokenAdminRegistryAddress);
        }

        vm.stopBroadcast();
    }


    function registry(address rebaseToken, address pool, address registryModuleOwnerCustomAddress, address tokenAdminRegistryAddress) public {
        RegistryModuleOwnerCustom registryModuleOwnerCustom = RegistryModuleOwnerCustom(registryModuleOwnerCustomAddress);
        registryModuleOwnerCustom.registerAdminViaOwner(address(rebaseToken));

        TokenAdminRegistry tokenAdminRegistry = TokenAdminRegistry(tokenAdminRegistryAddress);
        tokenAdminRegistry.acceptAdminRole(address(rebaseToken));
        tokenAdminRegistry.setPool(address(rebaseToken), address(pool));
    }

}


contract DeployVault is Script {
    function run(address owner, address rebaseTokenAddress) public returns (Vault vault) {
        vm.startBroadcast(owner);

        vault = new Vault(address(rebaseTokenAddress));

        RebaseToken(rebaseTokenAddress).addBurningAndMintingPermission(address(vault));

        vm.stopBroadcast();
    }
}
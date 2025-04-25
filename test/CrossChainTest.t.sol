// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import { Test } from "../lib/forge-std/src/Test.sol";

import { RebaseToken } from "../src/RebaseToken.sol";
import { RebaseTokenPool } from "../src/RebaseTokenPool.sol";
import { Vault } from "../src/Vault.sol";
import { IRebaseToken } from "../src/interface/IRebaseToken.sol";

import { TokenAndPoolDeployer, DeployVault } from "../script/Deployer.s.sol";
import { ConfigurePool } from "../script/ConfigurePool.s.sol";
import { BridgeTokens } from "../script/BridgeTokens.s.sol";


import { CCIPLocalSimulatorFork, Register } from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";


contract CrossChainTest is Test {
	uint256 private constant BALANCE_INITIAL = 100 ether;

    // Fork IDs
    uint256 public sepoliaForkId;
    uint256 public arbSepoliaForkId;

    // Chainlink Local Simulator Instance
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;

    // Selectors  (https://docs.chain.link/ccip/directory/testnet)
    uint64 public sepoliaChainSelector = 16015286601757825753;
    uint64 public arbSepoliaChainSelector = 3478487238524512106;

    // Addresses of contracts deployed in each fork
    RebaseToken public sepoliaContractAddress;
    RebaseToken public arbSepoliaContractAddress;
    RebaseTokenPool public sepoliaPool;
    RebaseTokenPool public arbPool;
    Register.NetworkDetails public sepoliaNetworkDetails;
    Register.NetworkDetails public arbNetworkDetails;
    Vault public vaultContractAddress;

    BridgeTokens public bridgeTokens;
    BridgeTokens public bridgeTokensArbitrum;
    

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");


    modifier depositRebaseToken() {
        vm.selectFork(arbSepoliaForkId);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, BALANCE_INITIAL);

        vm.selectFork(sepoliaForkId);
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, BALANCE_INITIAL);

        hoax(user, BALANCE_INITIAL);
        vaultContractAddress.deposit{value: BALANCE_INITIAL}();

        _;
    }


    function setUp() public {
        sepoliaForkId = vm.createSelectFork("sepolia-eth");
        arbSepoliaForkId = vm.createFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // SEPOLIA
        bridgeTokens = new BridgeTokens();
        TokenAndPoolDeployer tokenAndPoolDeployer = new TokenAndPoolDeployer();

        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        (sepoliaContractAddress, sepoliaPool) = tokenAndPoolDeployer.run(owner, sepoliaNetworkDetails.rmnProxyAddress, sepoliaNetworkDetails.routerAddress, sepoliaNetworkDetails.registryModuleOwnerCustomAddress, sepoliaNetworkDetails.tokenAdminRegistryAddress);

        DeployVault deployVault = new DeployVault();
        
        vaultContractAddress = deployVault.run(owner, address(sepoliaContractAddress));


        // ARBITRUM
        vm.selectFork(arbSepoliaForkId);
        bridgeTokensArbitrum = new BridgeTokens();
        tokenAndPoolDeployer = new TokenAndPoolDeployer();

        arbNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        (arbSepoliaContractAddress, arbPool) = tokenAndPoolDeployer.run(owner, arbNetworkDetails.rmnProxyAddress, arbNetworkDetails.routerAddress, arbNetworkDetails.registryModuleOwnerCustomAddress, arbNetworkDetails.tokenAdminRegistryAddress);


        // CONFIGURE POOLS
        ConfigurePool configurePool = new ConfigurePool();
        configurePool.run({
            ownerAddress: owner,
            localPool: address(arbPool), 
            remoteChainSelector: sepoliaNetworkDetails.chainSelector, 
            remotePool: address(sepoliaPool), 
            remoteToken: address(sepoliaContractAddress), 
            outboundRateLimiterIsEnabled: false,
            outboundRateLimiterCapacity: 0,
            outboundRateLimiterRate: 0, 
            inboundRateLimiterIsEnabled: false,
            inboundRateLimiterCapacity: 0,
            inboundRateLimiterRate: 0
        });

        // SEPOLIA
        vm.selectFork(sepoliaForkId);

        configurePool = new ConfigurePool();
        configurePool.run({
            ownerAddress: owner,
            localPool: address(sepoliaPool), 
            remoteChainSelector: arbNetworkDetails.chainSelector, 
            remotePool: address(arbPool), 
            remoteToken: address(arbSepoliaContractAddress), 
            outboundRateLimiterIsEnabled: false,
            outboundRateLimiterCapacity: 0,
            outboundRateLimiterRate: 0, 
            inboundRateLimiterIsEnabled: false,
            inboundRateLimiterCapacity: 0,
            inboundRateLimiterRate: 0
        });
    }


    function sendMessage(uint256 forkId) public {
        ccipLocalSimulatorFork.switchChainAndRouteMessage(forkId);
    }


    // See if transfers are working
    function testCrossChainTransferFunctionality() public depositRebaseToken()  {
        // Sending tokens to Arbitrum
        bridgeTokens.run(user, address(sepoliaContractAddress), BALANCE_INITIAL, sepoliaNetworkDetails, arbNetworkDetails);

        sendMessage(arbSepoliaForkId);

        vm.selectFork(sepoliaForkId);
        uint256 balanceUserSepolia = sepoliaContractAddress.balanceOf(user);

        vm.selectFork(arbSepoliaForkId);
        uint256 balanceUserArbitrum = arbSepoliaContractAddress.balanceOf(user);

        assertEq(balanceUserSepolia, 0);
        assertEq(balanceUserArbitrum, BALANCE_INITIAL);


        // Returning tokens to Sepolia
        bridgeTokensArbitrum.run(user, address(arbSepoliaContractAddress), BALANCE_INITIAL, arbNetworkDetails, sepoliaNetworkDetails);

        sendMessage(sepoliaForkId);

        balanceUserSepolia = sepoliaContractAddress.balanceOf(user);

        vm.selectFork(arbSepoliaForkId);
        balanceUserArbitrum = arbSepoliaContractAddress.balanceOf(user);
        uint256 userInterestRateArbitrum = arbSepoliaContractAddress.getUserInterestRate(user);

        assertEq(balanceUserSepolia, BALANCE_INITIAL);
        assertEq(balanceUserArbitrum, 0);
        assertEq(userInterestRateArbitrum, 5e10);
    }

    function testCrossChainInterestFunctionality() public depositRebaseToken() {
        // Test interest on the Sepolia Blockchain
        uint256 balanceUserSepoliaBefore = sepoliaContractAddress.balanceOf(user);

        vm.warp(block.timestamp + 60 minutes);

        uint256 balanceUserSepoliaAfter = sepoliaContractAddress.balanceOf(user);

        assertGt(balanceUserSepoliaAfter, balanceUserSepoliaBefore);


        // Sending tokens to Arbitrum
        bridgeTokens.run(user, address(sepoliaContractAddress), balanceUserSepoliaAfter, sepoliaNetworkDetails, arbNetworkDetails);

        sendMessage(arbSepoliaForkId);

        vm.selectFork(sepoliaForkId);
        uint256 balanceUserSepolia = sepoliaContractAddress.balanceOf(user);

        vm.selectFork(arbSepoliaForkId);
        uint256 balanceUserArbitrum = arbSepoliaContractAddress.balanceOf(user);

        assertEq(balanceUserSepolia, 0);
        assertEq(balanceUserArbitrum, balanceUserSepoliaAfter);


        // Test interest on the Arbitum Blockchain
        vm.warp(block.timestamp + 60 minutes);

        uint256 balanceUserArbitrumAfter = arbSepoliaContractAddress.balanceOf(user);

        assertGt(balanceUserArbitrumAfter, balanceUserArbitrum);
    }

}
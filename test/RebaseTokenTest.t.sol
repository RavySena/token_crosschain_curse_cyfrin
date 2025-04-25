// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {Test, console} from "../lib/forge-std/src/Test.sol";

import { RebaseToken } from "../src/RebaseToken.sol";
import { Vault } from "../src/Vault.sol";

import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20Errors } from "../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

import  "../script/Deployer.s.sol";


contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    uint256 private constant BALANCE_INITIAL = 100 ether;


    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");


    modifier depositRebaseToken() {
        hoax(user, BALANCE_INITIAL);
        vault.deposit{value: BALANCE_INITIAL}();
        _;
    }


    function setUp() public {
        TokenAndPoolDeployer deployerTokenRebase = new TokenAndPoolDeployer();
        DeployVault deployerVault = new DeployVault();

        (rebaseToken,) = deployerTokenRebase.run(owner, address(0), address(0), address(0), address(0));
        vault = deployerVault.run(owner, address(rebaseToken));
    }



    /* ------------------------- mint/deposit ------------------------- */
    function testMintFunctionality(uint256 amount) public {
        amount = bound(amount, 1 ether, BALANCE_INITIAL);

        hoax(user, BALANCE_INITIAL);
        vault.deposit{value: amount}();

        assertEq(rebaseToken.balanceOf(user), amount);
        assertEq(address(vault).balance, amount);
        assertEq(rebaseToken.totalSupply(), amount);
    }


    function testMintUserWithoutPermission() public {
        vm.expectRevert(abi.encodeWithSelector(RebaseToken.insufficientPermissionsToBurnAndMint.selector));
        rebaseToken.mint(user, BALANCE_INITIAL, 5e10);
    }


    /* ------------------------- burn/reedem ------------------------- */
    function testBurnFunctionality(uint256 amount) public {
        amount = bound(amount, 1 ether, BALANCE_INITIAL);

        hoax(user, BALANCE_INITIAL);
        vault.deposit{value: amount}();

        assertEq(rebaseToken.balanceOf(user), amount);
        assertEq(address(vault).balance, amount);
        assertEq(rebaseToken.totalSupply(), amount);

        vm.prank(user);
        vault.reedem(amount);

        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(vault).balance, 0);
        assertEq(rebaseToken.totalSupply(), 0);
    }


    function testBurnUserWithoutPermission() public {
        vm.expectRevert(abi.encodeWithSelector(RebaseToken.insufficientPermissionsToBurnAndMint.selector));
        rebaseToken.burn(user, BALANCE_INITIAL);
    }


    /* ------------------------- transfer ------------------------- */
    function testTransferFunctionality() public depositRebaseToken() {
        uint256 balanceUserBeforeTransfer = rebaseToken.balanceOf(user);

        vm.prank(user);
        rebaseToken.transfer(user2, balanceUserBeforeTransfer / 2);

        uint256 balanceUserAfterTransfer = rebaseToken.balanceOf(user);
        uint256 balanceUser2AfterTransfer = rebaseToken.balanceOf(user2);

        assertEq(balanceUserBeforeTransfer / 2, balanceUserAfterTransfer);
        assertEq(balanceUser2AfterTransfer, balanceUserBeforeTransfer / 2);
    }

    function testTransferMoreThanTheBalance() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, 0, BALANCE_INITIAL));
        vm.prank(user);
        rebaseToken.transfer(user2, BALANCE_INITIAL);

        hoax(user, BALANCE_INITIAL);
        vault.deposit{value: BALANCE_INITIAL}();

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, BALANCE_INITIAL, BALANCE_INITIAL * 2));
        vm.prank(user);
        rebaseToken.transfer(user2, BALANCE_INITIAL * 2);

        uint256 balanceUser2 = rebaseToken.balanceOf(user2);
        assertEq(balanceUser2, 0);
    }


    /* ------------------------- transferFrom ------------------------- */
    function testTransferFromFunctionality() public depositRebaseToken() {
        vm.prank(user);
        rebaseToken.approve(user, BALANCE_INITIAL);

        vm.prank(user);
        rebaseToken.transferFrom(user, user2, type(uint256).max);

        uint256 balanceUser = rebaseToken.balanceOf(user);
        uint256 balanceUser2 = rebaseToken.balanceOf(user2);

        assertEq(balanceUser, 0);
        assertEq(balanceUser2, BALANCE_INITIAL);
    }


    function testTransferFromMoreThanTheBalance() public depositRebaseToken() {
        vm.prank(user);
        rebaseToken.approve(user, BALANCE_INITIAL * 2);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, BALANCE_INITIAL, BALANCE_INITIAL * 2));
        vm.prank(user);
        rebaseToken.transferFrom(user, user2, BALANCE_INITIAL * 2);

        uint256 balanceUser = rebaseToken.balanceOf(user);
        uint256 balanceUser2 = rebaseToken.balanceOf(user2);

        assertEq(balanceUser, BALANCE_INITIAL);
        assertEq(balanceUser2, 0);
    }


    function testTransferFromMoreThanApproved() public depositRebaseToken() {
        vm.prank(user);
        rebaseToken.approve(user, BALANCE_INITIAL / 2);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, user, BALANCE_INITIAL / 2, BALANCE_INITIAL));
        vm.prank(user);
        rebaseToken.transferFrom(user, user2, BALANCE_INITIAL);

        uint256 balanceUser = rebaseToken.balanceOf(user);
        uint256 balanceUser2 = rebaseToken.balanceOf(user2);

        assertEq(balanceUser, BALANCE_INITIAL);
        assertEq(balanceUser2, 0);
    }



    /* ------------------------- setInterest ------------------------- */
    function testSetInterestFunctionality() public {
        vm.prank(owner);
        rebaseToken.setInterest(4e10);

        uint256 interestAfterChange = rebaseToken.getInterestRate();
        assertEq(interestAfterChange, 4e10);

        vm.prank(owner);
        rebaseToken.setInterest(2e10);

        interestAfterChange = rebaseToken.getInterestRate();
        assertEq(interestAfterChange, 2e10);
    }


    function testSetInterestRaisingInterestRates() public {
        vm.expectRevert(abi.encodeWithSelector(RebaseToken.interestChangeGreaterThanPreviousInterest.selector, 6e10));
        vm.prank(owner);
        rebaseToken.setInterest(6e10);
    }


    function testSetInterestUserWithoutPermission() public {
        vm.prank(owner);
        rebaseToken.addBurningAndMintingPermission(user);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, msg.sender));
        vm.prank(msg.sender);
        rebaseToken.setInterest(1e10);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        vm.prank(user);
        rebaseToken.setInterest(1e10);
    }


    /* ------------------------- addBurningAndMintingPermission ------------------------- */
     function testAddBurningAndMintingPermissionFunctionality() public {
        vm.prank(owner);
        rebaseToken.addBurningAndMintingPermission(user);

        uint256 balanceUserBeforeTheMinting = rebaseToken.balanceOf(user);

        vm.prank(user);
        rebaseToken.mint(user, BALANCE_INITIAL, 5e10);

        uint256 balanceUserAfterTheMinting = rebaseToken.balanceOf(user);

        assert(balanceUserAfterTheMinting > balanceUserBeforeTheMinting);
        assertEq(balanceUserAfterTheMinting, BALANCE_INITIAL);
     }


    /* ------------------------- removeBurningAndMintingPermission ------------------------- */
     function testRemoveBurningAndMintingPermissionFunctionality() public {
        vm.prank(owner);
        rebaseToken.addBurningAndMintingPermission(user);

        uint256 balanceUserBeforeTheMinting = rebaseToken.balanceOf(user);

        vm.prank(user);
        rebaseToken.mint(user, BALANCE_INITIAL, 5e10);

        uint256 balanceUserAfterTheMinting = rebaseToken.balanceOf(user);
        
        assert(balanceUserAfterTheMinting > balanceUserBeforeTheMinting);
        assertEq(balanceUserAfterTheMinting, BALANCE_INITIAL);

        vm.prank(owner);
        rebaseToken.removeBurningAndMintingPermission(user);

        balanceUserBeforeTheMinting = rebaseToken.balanceOf(user);

        vm.expectRevert(abi.encodeWithSelector(RebaseToken.insufficientPermissionsToBurnAndMint.selector));
        vm.prank(user);
        rebaseToken.mint(user, BALANCE_INITIAL, 5e10);
     }


    /* ------------------------- Fees ------------------------- */
    function testFeesFunctionality() public depositRebaseToken() {
        uint256 balanceUserBefore = rebaseToken.balanceOf(user);

        vm.warp(block.timestamp + 60 minutes);

        uint256 balanceUserAfter = rebaseToken.balanceOf(user);

        assert(balanceUserAfter > balanceUserBefore);
    }


    function testFeesTransfer() public depositRebaseToken() {
        vm.prank(user);
        rebaseToken.transfer(user2, type(uint256).max);

        uint256 balanceUserBefore = rebaseToken.balanceOf(user2);

        vm.warp(block.timestamp + 60 minutes);

        uint256 balanceUserAfter = rebaseToken.balanceOf(user2);

        assert(balanceUserAfter > balanceUserBefore);
    }


    function testFeesDepositAfterInterestRateChange() public depositRebaseToken() {
        uint256 interestRateUserBefore = rebaseToken.getUserInterestRate(user);

        vm.prank(owner);
        rebaseToken.setInterest(3e10);

        hoax(user, BALANCE_INITIAL);
        vault.deposit{value: BALANCE_INITIAL}();

        uint256 interestRateUserAfter = rebaseToken.getUserInterestRate(user);

        assert(interestRateUserBefore > interestRateUserAfter);
        assertEq(interestRateUserAfter, 3e10);
    }

}
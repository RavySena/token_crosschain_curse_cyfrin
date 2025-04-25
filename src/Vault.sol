// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import { IRebaseToken } from "./interface/IRebaseToken.sol";
import {console} from "../lib/forge-std/src/Test.sol";


contract Vault {
    /*------------------------------------------ TYPE DECLARATIONS -------------------------------------------*/
    IRebaseToken rebaseToken;


    /*------------------------------------------------ EVENTS ------------------------------------------------*/
    event Reedem(address, uint256);


    /*------------------------------------------------ ERRORS ------------------------------------------------*/
    error redeemWasNotCompletedSuccessfully();


    constructor(address rebaseTokenAddress) {
        rebaseToken = IRebaseToken(rebaseTokenAddress);
    }


    
    /*------------------------------------------         -----------------------------------------------------*/
    /*------------------------------------------ FUNCTIONS PUBLICS -------------------------------------------*/
    /*----------------------------------------------------         -------------------------------------------*/
    function deposit() public payable {
        uint256 interestRate = rebaseToken.getInterestRate();
        rebaseToken.mint(msg.sender, msg.value, interestRate);
    }


    function reedem(uint256 amount) public {
        if (amount == type(uint256).max) {
            amount = rebaseToken.balanceOf(msg.sender);
        }

        rebaseToken.burn(msg.sender, amount);
        (bool success,) = payable(msg.sender).call{value: amount}("");

        if (!success) {
            revert redeemWasNotCompletedSuccessfully();
        }

        emit Reedem(msg.sender, amount);
    }

}
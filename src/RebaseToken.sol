// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "../lib/forge-std/src/Test.sol";


contract RebaseToken is ERC20, Ownable {
    /*------------------------------------------ TYPE DECLARATIONS -------------------------------------------*/
    mapping(address user => uint256 fees) private s_percentageInterest;
    mapping(address user => uint256 blocktimestamp) private s_lastBlocktimestamp;
    mapping(address addressAllowed => bool allowed) private s_permissionsBurningAndMinting;


    /*----------------------------------------------- VARIABLES ----------------------------------------------*/
    uint256 private s_currentInterest = 5e10;
    

    /*----------------------------------------------- CONSTANTS ----------------------------------------------*/
    uint256 private constant PRECISION_FACTOR = 1e18;


    /*------------------------------------------------ EVENTS ------------------------------------------------*/
    event interestPercentageChanged(uint256 newInterest);
    event changeInPermissions(address, string);


    /*------------------------------------------------ ERRORS ------------------------------------------------*/
    error interestChangeGreaterThanPreviousInterest(uint256 newInterest);
    error insufficientPermissionsToBurnAndMint();

    
    /*---------------------------------------------- MODIFIERS -----------------------------------------------*/
    modifier onlyBurnerAndMinter() {
        if (!s_permissionsBurningAndMinting[msg.sender]) {
            revert insufficientPermissionsToBurnAndMint();
        }

        _;
    }


    constructor () ERC20("Rebase Token", "RBT") Ownable(msg.sender) {
    }


    /*------------------------------------------         -----------------------------------------------------*/
    /*------------------------------------------ FUNCTIONS PUBLICS -------------------------------------------*/
    /*----------------------------------------------------         -------------------------------------------*/
    function transfer(address to, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(to);
        
        if (type(uint256).max == amount) {
            amount = balanceOf(msg.sender);
        }

        if (s_percentageInterest[to] == 0) {
            s_percentageInterest[to] = s_currentInterest;
        }

        return super.transfer(to, amount);
    }


    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(from);
        _mintAccruedInterest(to);

        if (type(uint256).max == amount) {
            amount = balanceOf(from);
        }

        if (s_percentageInterest[to] == 0) {
            s_percentageInterest[to] = s_currentInterest;
        }

        return super.transferFrom(from, to, amount);
    }


    /*------------------------------------------         -----------------------------------------------------*/
    /*------------------------------------------ FUNCTIONS EXTERNAL ------------------------------------------*/
    /*----------------------------------------------------          ------------------------------------------*/
    function mint(address user, uint256 amount, uint256 _interestRate) external onlyBurnerAndMinter() {
        _mintAccruedInterest(user);

        s_percentageInterest[user] = _interestRate;

        _mint(user, amount);
    }


    function burn(address user, uint256 amount) external onlyBurnerAndMinter() {
        _mintAccruedInterest(user);

        if (amount == type(uint256).max) {
            amount = balanceOf(user);
        }

        _burn(user, amount);
    }
    
    
    function setInterest(uint256 newInterest) external onlyOwner() {
        if (newInterest > s_currentInterest) {
            revert interestChangeGreaterThanPreviousInterest(newInterest);
        }

        s_currentInterest = newInterest;

        emit interestPercentageChanged(newInterest);
    }


    function addBurningAndMintingPermission(address addressAllowed) external onlyOwner() {
        s_permissionsBurningAndMinting[addressAllowed] = true;

        emit changeInPermissions(addressAllowed, "Permission granted");
    }


    function removeBurningAndMintingPermission(address addressRemove) external onlyOwner() {
        s_permissionsBurningAndMinting[addressRemove] = false;

        emit changeInPermissions(addressRemove, "Permission removed.");
    }


    /*-----------------------------------               ------------------------------------------------------*/
    /*----------------------------------- FUNCTIONS INTERNAL AND PRIVATES ------------------------------------*/
    /*---------------------------------------------------                 ------------------------------------*/
    function _mintAccruedInterest(address _user) internal {
        uint256 accruedInterest = balanceOf(_user) - super.balanceOf(_user);

        s_lastBlocktimestamp[_user] = block.timestamp;

        _mint(_user, accruedInterest);
    }


    /*------------------------------------------         -----------------------------------------------------*/
    /*------------------------------------------ FUNCTIONS GETTERS -------------------------------------------*/
    /*----------------------------------------------------         -------------------------------------------*/
    function balanceOf(address user) public override view returns (uint256) {
        return super.balanceOf(user) * _calculateAccruedInterest(user) / PRECISION_FACTOR;
    }


    function _calculateAccruedInterest(address _user) private view returns (uint256) {
        uint256 timeElapsed = block.timestamp - s_lastBlocktimestamp[_user];
        return s_percentageInterest[_user] * timeElapsed + PRECISION_FACTOR;  // Isso esta adicionando juros por segundo
    }


    function getInterestRate() public view returns (uint256) {
        return s_currentInterest;
    }

    function getUserInterestRate(address user) public view returns (uint256) {
        return s_percentageInterest[user];
    }

}
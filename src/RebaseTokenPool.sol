// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "../lib/forge-std/src/Script.sol";
import { IRebaseToken } from "./interface/IRebaseToken.sol";

import { TokenPool } from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import { Pool } from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import { IPoolV1 } from "@ccip/contracts/src/v0.8/ccip/interfaces/IPool.sol";
import { IERC20 } from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";


contract RebaseTokenPool is TokenPool {
    constructor(address _token, address[] memory _allowlist, address _rmnProxy, address _router) TokenPool(IERC20(_token), _allowlist, _rmnProxy, _router) {
    }


    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) external override returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurn(lockOrBurnIn);

        IRebaseToken rebaseToken = IRebaseToken(address(i_token));
        uint256 userInterestRate = rebaseToken.getUserInterestRate(lockOrBurnIn.originalSender);

        rebaseToken.burn(address(this), lockOrBurnIn.amount);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }


    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external override returns (Pool.ReleaseOrMintOutV1 memory) {
        _validateReleaseOrMint(releaseOrMintIn);

        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));

        IRebaseToken rebaseToken = IRebaseToken(address(i_token));
        rebaseToken.mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate);

        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }

}

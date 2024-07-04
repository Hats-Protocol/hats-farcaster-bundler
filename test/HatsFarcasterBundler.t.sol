// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import { Test, console2 } from "forge-std/Test.sol";
import { HatsFarcasterBundler } from "../src/HatsFarcasterBundler.sol";
import { Deploy } from "../script/Deploy.s.sol";

contract HatsFarcasterBundlerTest is Deploy, Test {
  /// @dev Inherit from DeployPrecompiled instead of Deploy if working with pre-compiled contracts

  /// @dev variables inhereted from Deploy script
  // HatsFarcasterBundler public bundler;
  // bytes32 public SALT;

  uint256 public fork;
  uint256 public BLOCK_NUMBER;

  function setUp() public virtual {
    // OPTIONAL: create and activate a fork, at BLOCK_NUMBER
    // fork = vm.createSelectFork(vm.rpcUrl("mainnet"), BLOCK_NUMBER);

    // deploy via the script
    prepare(false);
    run();
  }
}

contract UnitTests is HatsFarcasterBundlerTest { }

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import {
  HatsFarcasterBundler, IHats, HatTemplate, FarcasterContracts, HatMintData
} from "../src/HatsFarcasterBundler.sol";

contract Deploy is Script {
  HatsFarcasterBundler public bundler;
  bytes32 public SALT = bytes32(abi.encode(0x4a57));

  // default values
  bool internal _verbose = true;
  string internal _version = "0.1.0";
  IHats internal _hats = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
  HatTemplate internal _topHatTemplate;
  HatTemplate internal _autonomousAdminHatTemplate;
  HatTemplate internal _adminHatTemplate;
  HatTemplate internal _casterHatTemplate;
  FarcasterContracts internal _farcasterContracts;

  function _setFarcasterContracts() internal {
    _farcasterContracts = FarcasterContracts({
      IdGateway: 0x00000000Fc25870C6eD6b6c7E41Fb078b7656f69,
      idRegistry: 0x00000000Fc6c5F01Fc30151999387Bb99A9f489b,
      keyGateway: 0x00000000fC56947c7E7183f8Ca4B62398CaAdf0B,
      keyRegistry: 0x00000000Fc1237824fb747aBDE0FF18990E59b7e,
      signedKeyRequestValidator: 0x00000000FC700472606ED4fA22623Acf62c60553
    });
  }

  /// @dev Override default values, if desired
  function prepare(bool verbose, string memory version, IHats hats, HatTemplate[] memory treeTemplate) public {
    _verbose = verbose;
    _version = version;
    _hats = hats;

    _topHatTemplate = treeTemplate[0];
    _autonomousAdminHatTemplate = treeTemplate[1];
    _adminHatTemplate = treeTemplate[2];
    _casterHatTemplate = treeTemplate[3];

    _setFarcasterContracts();
  }

  function _createTreeTemplate() internal pure virtual returns (HatTemplate[] memory treeTemplate) {
    // module placeholder address
    address modulePlaceholder = 0x0000000000000000000000000000000000004a57;

    treeTemplate = new HatTemplate[](4);

    // top hat
    treeTemplate[0] = HatTemplate({
      eligibility: address(0),
      maxSupply: 0,
      toggle: address(0),
      mutable_: false,
      details: "ipfs://bafkreigi7amzxywtped6uz5spo73n7zolxtymxeaqnwmizryv3mp46v63e",
      imageURI: "ipfs://bafkreiflezpk3kjz6zsv23pbvowtatnd5hmqfkdro33x5mh2azlhne3ah4"
    });

    // autonomous admin
    treeTemplate[1] = HatTemplate({
      eligibility: modulePlaceholder,
      maxSupply: 1,
      toggle: modulePlaceholder,
      mutable_: true,
      details: "ipfs://bafkreihe2rxghtnomgaxs5fv2suxog6bdxkgxxifik7z6gtu65mi3oycue",
      imageURI: ""
    });

    // admin hat
    treeTemplate[2] = HatTemplate({
      eligibility: modulePlaceholder,
      maxSupply: 5,
      toggle: modulePlaceholder,
      mutable_: true,
      details: "ipfs://bafkreiax5tjyhestv5op33cje6yrhsaylnblu7t6tl7w25qmhl4cojpap4",
      imageURI: ""
    });

    // caster hat
    treeTemplate[3] = HatTemplate({
      eligibility: modulePlaceholder,
      maxSupply: 1000,
      toggle: modulePlaceholder, // will be overriden by the first admin
      mutable_: true,
      details: "ipfs://bafkreig325iyeqwpzigo4anb2qjzux5lu4gww4ewna23pbtluys52pmtcy",
      imageURI: ""
    });
  }

  /// @dev Set up the deployer via their private key from the environment
  function deployer() public returns (address) {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    return vm.rememberKey(privKey);
  }

  function _log(string memory prefix) internal view {
    if (_verbose) {
      console2.log(string.concat(prefix, "HatsFarcasterBundler:"), address(bundler));
    }
  }

  /// @dev Deploy the contract to a deterministic address via forge's create2 deployer factory.
  function run() public virtual {
    vm.startBroadcast(deployer());

    // set the hat tree template
    HatTemplate[] memory treeTemplate;

    if (_autonomousAdminHatTemplate.eligibility == address(0)) {
      // if the templates are not provided, create them
      treeTemplate = _createTreeTemplate();
    } else {
      // otherwise, use the
      treeTemplate = new HatTemplate[](4);
      treeTemplate[0] = _topHatTemplate;
      treeTemplate[1] = _autonomousAdminHatTemplate;
      treeTemplate[2] = _adminHatTemplate;
      treeTemplate[3] = _casterHatTemplate;
    }

    _setFarcasterContracts();

    /**
     * @dev Deploy the contract to a deterministic address via forge's create2 deployer factory, which is at this
     * address on all chains: `0x4e59b44847b379578588920cA78FbF26c0B4956C`.
     * The resulting deployment address is determined by only two factors:
     *    1. The bytecode hash of the contract to deploy. Setting `bytecode_hash` to "none" in foundry.toml ensures that
     *       never differs regardless of where its being compiled
     *    2. The provided salt, `SALT`
     */
    bundler = new HatsFarcasterBundler{ salt: SALT }(_version, _hats, treeTemplate, _farcasterContracts);

    vm.stopBroadcast();

    _log("");
  }
}

/* FORGE CLI COMMANDS

## A. Simulate the deployment locally
forge script script/Deploy.s.sol -f mainnet

## B. Deploy to real network and verify on etherscan
forge script script/Deploy.s.sol -f mainnet --broadcast --verify

## C. Fix verification issues (replace values in curly braces with the actual values)
forge verify-contract --chain-id 1 --num-of-optimizations 1000000 --watch --constructor-args $(cast abi-encode \
 "constructor({args})" "{arg1}" "{arg2}" "{argN}" ) \ 
 --compiler-version v0.8.19 {deploymentAddress} \
 src/{Counter}.sol:{Counter} --etherscan-api-key $ETHERSCAN_KEY

## D. To verify ir-optimized contracts on etherscan...
  1. Run (C) with the following additional flag: `--show-standard-json-input > etherscan.json`
  2. Patch `etherscan.json`: `"optimizer":{"enabled":true,"runs":100}` =>
`"optimizer":{"enabled":true,"runs":100},"viaIR":true`
  3. Upload the patched `etherscan.json` to etherscan manually

  See this github issue for more: https://github.com/foundry-rs/foundry/issues/3507#issuecomment-1465382107

*/

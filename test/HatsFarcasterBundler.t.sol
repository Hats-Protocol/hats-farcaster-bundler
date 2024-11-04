// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import {
  HatsFarcasterBundler,
  FarcasterDelegatorLike,
  IHats,
  HatTemplate,
  FarcasterContracts,
  HatMintData
} from "../src/HatsFarcasterBundler.sol";
import { HatsFarcasterBundlerHarness } from "../test/harness/HatsFarcasterBundlerHarness.sol";
import { HatsModuleFactory } from "../lib/hats-module/src/HatsModuleFactory.sol";
import { Deploy } from "../script/Deploy.s.sol";

contract HatsFarcasterBundlerTest is Deploy, Test {
  /// @dev variables inherited from Deploy script
  // HatsFarcasterBundler public bundler;
  // bytes32 public SALT;

  // test environment
  uint256 public fork;
  uint256 public BLOCK_NUMBER;
  FarcasterContracts public farcasterContracts = FarcasterContracts({
    IdGateway: 0x00000000Fc25870C6eD6b6c7E41Fb078b7656f69,
    idRegistry: 0x00000000Fc6c5F01Fc30151999387Bb99A9f489b,
    keyGateway: 0x00000000fC56947c7E7183f8Ca4B62398CaAdf0B,
    keyRegistry: 0x00000000Fc1237824fb747aBDE0FF18990E59b7e,
    signedKeyRequestValidator: 0x00000000FC700472606ED4fA22623Acf62c60553
  });
  address public delegatorImplementation = 0xa947334C33daDca4BcBb396395eCFD66601BB38c;
  HatsModuleFactory public factory = HatsModuleFactory(0x0a3f85fa597B6a967271286aA0724811acDF5CD9);

  // deploy params
  string public version = "test";
  IHats public hats = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
  HatTemplate public topHatTemplate;
  HatTemplate public autonomousAdminHatTemplate;
  HatTemplate public adminHatTemplate;
  HatTemplate public casterHatTemplate;

  // test accounts
  address[] public accounts;

  function _createTreeTemplate() internal pure override returns (HatTemplate[] memory treeTemplate) {
    // module placeholder address
    address modulePlaceholder = 0x0000000000000000000000000000000000004a57;

    treeTemplate = new HatTemplate[](4);

    // top hat
    treeTemplate[0] = HatTemplate({
      eligibility: address(0),
      maxSupply: 0,
      toggle: address(0),
      mutable_: false,
      details: "top hat details",
      imageURI: "top hat image"
    });

    // autonomous admin
    treeTemplate[1] = HatTemplate({
      eligibility: modulePlaceholder,
      maxSupply: 1,
      toggle: modulePlaceholder,
      mutable_: true,
      details: "autonomous admin details",
      imageURI: "autonomous admin image"
    });

    // admin hat
    treeTemplate[2] = HatTemplate({
      eligibility: modulePlaceholder,
      maxSupply: 5,
      toggle: modulePlaceholder,
      mutable_: true,
      details: "admin details",
      imageURI: "admin image"
    });

    // caster hat
    treeTemplate[3] = HatTemplate({
      eligibility: modulePlaceholder,
      maxSupply: 100,
      toggle: modulePlaceholder, // will be overriden by the first admin
      mutable_: true,
      details: "caster details",
      imageURI: "caster image"
    });
  }

  function setUp() public virtual {
    // create the test accounts
    uint256 count = 20;
    accounts = new address[](count);
    for (uint256 i; i < count; ++i) {
      accounts[i] = address(uint160(uint256(i + 1)));
    }

    // OPTIONAL: create and activate a fork, at BLOCK_NUMBER
    BLOCK_NUMBER = 117_616_200; // after deployment of HatsModuleFactory v0.7.0 on OP Mainnet
    fork = vm.createSelectFork(vm.rpcUrl("optimism"), BLOCK_NUMBER);

    // set the tree template
    HatTemplate[] memory treeTemplate = _createTreeTemplate();

    // store the templates for future reference
    topHatTemplate = treeTemplate[0];
    autonomousAdminHatTemplate = treeTemplate[1];
    adminHatTemplate = treeTemplate[2];
    casterHatTemplate = treeTemplate[3];

    // deploy via the script
    prepare(false, version, hats, treeTemplate);
    run();
  }
}

contract Deployment is HatsFarcasterBundlerTest {
  function test_HATS() public view {
    assertEq(address(bundler.HATS()), address(hats));
  }

  function test_version() public view {
    assertEq(bundler.version(), version);
  }

  function test_topHatTemplate() public view {
    (
      address eligibility,
      uint256 maxSupply,
      address toggle,
      bool mutable_,
      string memory details,
      string memory imageURI
    ) = bundler.topHatTemplate();
    assertEq(eligibility, topHatTemplate.eligibility);
    assertEq(maxSupply, topHatTemplate.maxSupply);
    assertEq(toggle, topHatTemplate.toggle);
    assertEq(mutable_, topHatTemplate.mutable_);
    assertEq(details, topHatTemplate.details);
    assertEq(imageURI, topHatTemplate.imageURI);
  }

  function test_autonomousAdminTemplate() public view {
    (
      address eligibility,
      uint256 maxSupply,
      address toggle,
      bool mutable_,
      string memory details,
      string memory imageURI
    ) = bundler.autonomousAdminHatTemplate();
    assertEq(eligibility, autonomousAdminHatTemplate.eligibility);
    assertEq(maxSupply, autonomousAdminHatTemplate.maxSupply);
    assertEq(toggle, autonomousAdminHatTemplate.toggle);
    assertEq(mutable_, autonomousAdminHatTemplate.mutable_);
    assertEq(details, autonomousAdminHatTemplate.details);
    assertEq(imageURI, autonomousAdminHatTemplate.imageURI);
  }

  function test_adminTemplate() public view {
    (
      address eligibility,
      uint256 maxSupply,
      address toggle,
      bool mutable_,
      string memory details,
      string memory imageURI
    ) = bundler.adminHatTemplate();
    assertEq(eligibility, adminHatTemplate.eligibility);
    assertEq(maxSupply, adminHatTemplate.maxSupply);
    assertEq(toggle, adminHatTemplate.toggle);
    assertEq(mutable_, adminHatTemplate.mutable_);
    assertEq(details, adminHatTemplate.details);
    assertEq(imageURI, adminHatTemplate.imageURI);
  }

  function test_casterTemplate() public view {
    (
      address eligibility,
      uint256 maxSupply,
      address toggle,
      bool mutable_,
      string memory details,
      string memory imageURI
    ) = bundler.casterHatTemplate();
    assertEq(eligibility, casterHatTemplate.eligibility);
    assertEq(maxSupply, casterHatTemplate.maxSupply);
    assertEq(toggle, casterHatTemplate.toggle);
    assertEq(mutable_, casterHatTemplate.mutable_);
    assertEq(details, casterHatTemplate.details);
    assertEq(imageURI, casterHatTemplate.imageURI);
  }

  function test_farcasterContracts() public view {
    (address idGateway, address idRegistry, address keyGateway, address keyRegistry, address signedKeyRequestValidator)
    = bundler.farcasterContracts();
    assertEq(idGateway, farcasterContracts.IdGateway);
    assertEq(idRegistry, farcasterContracts.idRegistry);
    assertEq(keyGateway, farcasterContracts.keyGateway);
    assertEq(keyRegistry, farcasterContracts.keyRegistry);
    assertEq(signedKeyRequestValidator, farcasterContracts.signedKeyRequestValidator);
  }
}

contract HarnessTest is HatsFarcasterBundlerTest {
  HatsFarcasterBundlerHarness public harness;

  function setUp() public override {
    super.setUp();

    // set up the tree template
    HatTemplate[] memory treeTemplate = new HatTemplate[](4);
    treeTemplate[0] = topHatTemplate;
    treeTemplate[1] = autonomousAdminHatTemplate;
    treeTemplate[2] = adminHatTemplate;
    treeTemplate[3] = casterHatTemplate;

    // deploy the harness
    harness = new HatsFarcasterBundlerHarness(version, hats, treeTemplate, farcasterContracts);
  }

  function getImmutableArgs(uint256 _adminHat) internal view returns (bytes memory) {
    return abi.encodePacked(
      _adminHat,
      farcasterContracts.IdGateway,
      farcasterContracts.idRegistry,
      farcasterContracts.keyGateway,
      farcasterContracts.keyRegistry,
      farcasterContracts.signedKeyRequestValidator
    );
  }

  function test_predictAdminAndCasterHatIds() public view {
    // the next top hat id is 43
    uint256 topHatId = (uint256(hats.lastTopHatId()) + 1) << 224;
    // console2.log("topHatId", topHatId);
    assertEq(topHatId, 0x0000005200000000000000000000000000000000000000000000000000000000); // 82

    (uint256 adminHatId, uint256 casterHatId) = harness.predictAdminAndCasterHatIds();
    assertEq(adminHatId, 0x0000005200010001000000000000000000000000000000000000000000000000); // 82.1.1
    assertEq(casterHatId, 0x0000005200010001000100000000000000000000000000000000000000000000); // 82.1.1.1
  }

  function testFuzz_getHatsFarcasterDelegatorOtherImmutableArgs(uint256 _adminHat) public view {
    bytes memory args = getImmutableArgs(_adminHat);
    bytes memory retargs = harness.getHatsFarcasterDelegatorOtherImmutableArgs(_adminHat);
    assertEq(args, retargs);
  }

  function test_getHatsFarcasterDelegatorOtherImmutableArgs() public view {
    testFuzz_getHatsFarcasterDelegatorOtherImmutableArgs(1);
  }

  // FIXME figure out how to make this run faster; probably has to do with fetching the forked state for each of the
  // ~randomly generated addresses
  // function testFuzz_createHatsFarcasterDelegator(uint256 _adminHat, uint256 _casterHat, uint256 _saltNonce) public {
  //   address predictedAddress =
  //     factory.getHatsModuleAddress(delegatorImplementation, _casterHat, getImmutableArgs(_adminHat), _saltNonce);

  //   address deployedAddress =
  //     harness.createHatsFarcasterDelegator(factory, delegatorImplementation, _adminHat, _casterHat, _saltNonce);

  //   assertEq(predictedAddress, deployedAddress, "incorrect address");

  //   uint256 codeSize;
  //   assembly {
  //     codeSize := extcodesize(deployedAddress)
  //   }
  //   assertGt(codeSize, 0, "deployedAddress has no code");
  // }

  function test_createHatsFarcasterDelegator_deployment() public {
    uint256 adminHat = 1;
    uint256 casterHat = 1;
    uint256 saltNonce = 1;

    address predictedAddress =
      factory.getHatsModuleAddress(delegatorImplementation, casterHat, getImmutableArgs(adminHat), saltNonce);

    address deployedAddress =
      harness.createHatsFarcasterDelegator(factory, delegatorImplementation, adminHat, casterHat, saltNonce);

    // the predicted address should be the same as the deployed address
    assertEq(predictedAddress, deployedAddress);

    // the deployed address should have code
    uint256 codeSize;
    assembly {
      codeSize := extcodesize(deployedAddress)
    }
    assertGt(codeSize, 0, "deployedAddress has no code");
  }

  function test_createHatsTree(uint256 _casterEligibilityIndex) public {
    console2.log("accounts.length", accounts.length);
    address casterEligibility = accounts[bound(_casterEligibilityIndex, 0, accounts.length - 1)];

    uint256[] memory hatIds = harness.createHatsTree(casterEligibility);

    string memory details;
    uint32 maxSupply;
    // uint32 supply;
    address eligibility;
    address toggle;
    string memory imageURI;
    // uint16 lastHatId;
    bool mutable_;
    // bool active;

    // top hat properties
    (details, maxSupply,, eligibility, toggle, imageURI,, mutable_,) = hats.viewHat(hatIds[0]);
    assertEq(details, topHatTemplate.details, "top hat details");
    assertEq(maxSupply, 1, "top hat maxSupply"); // top hats always have a max supply of 1
    assertEq(eligibility, topHatTemplate.eligibility, "top hat eligibility");
    assertEq(toggle, topHatTemplate.toggle, "top hat toggle");
    assertEq(imageURI, topHatTemplate.imageURI, "top hat imageURI");
    assertEq(mutable_, topHatTemplate.mutable_, "top hat mutable_");
    assertEq(hatIds[0], 0x0000005200000000000000000000000000000000000000000000000000000000); // 82

    // autonomous admin hat properties
    (details, maxSupply,, eligibility, toggle, imageURI,, mutable_,) = hats.viewHat(hatIds[1]);
    assertEq(details, autonomousAdminHatTemplate.details, "autonomous admin hat details");
    assertEq(maxSupply, autonomousAdminHatTemplate.maxSupply, "autonomous admin hat maxSupply");
    assertEq(eligibility, autonomousAdminHatTemplate.eligibility, "autonomous admin hat eligibility");
    assertEq(toggle, autonomousAdminHatTemplate.toggle, "autonomous admin hat toggle");
    assertEq(imageURI, autonomousAdminHatTemplate.imageURI, "autonomous admin hat imageURI");
    assertEq(mutable_, autonomousAdminHatTemplate.mutable_, "autonomous admin hat mutable_");
    assertEq(hatIds[1], 0x0000005200010000000000000000000000000000000000000000000000000000); // 82

    // admin hat properties
    (details, maxSupply,, eligibility, toggle, imageURI,, mutable_,) = hats.viewHat(hatIds[2]);
    assertEq(details, adminHatTemplate.details, "admin hat details");
    assertEq(maxSupply, adminHatTemplate.maxSupply, "admin hat maxSupply");
    assertEq(eligibility, adminHatTemplate.eligibility, "admin hat eligibility");
    assertEq(toggle, adminHatTemplate.toggle, "admin hat toggle");
    assertEq(imageURI, adminHatTemplate.imageURI, "admin hat imageURI");
    assertEq(mutable_, adminHatTemplate.mutable_, "admin hat mutable_");
    assertEq(hatIds[2], 0x0000005200010001000000000000000000000000000000000000000000000000); // 82.1.1

    // caster hat properties
    (details, maxSupply,, eligibility, toggle, imageURI,, mutable_,) = hats.viewHat(hatIds[3]);
    assertEq(details, casterHatTemplate.details, "caster hat details");
    assertEq(maxSupply, casterHatTemplate.maxSupply, "caster hat maxSupply");
    assertEq(eligibility, casterEligibility, "caster hat eligibility");
    assertEq(toggle, casterHatTemplate.toggle, "caster hat toggle");
    assertEq(imageURI, casterHatTemplate.imageURI, "caster hat imageURI");
    assertEq(mutable_, casterHatTemplate.mutable_, "caster hat mutable_");
    assertEq(hatIds[3], 0x0000005200010001000100000000000000000000000000000000000000000000); // 82.1.1.1
  }

  function testFuzz_constructHatMintData(uint256 _hatId, uint8 _wearerCount) public view {
    vm.assume(_wearerCount > 0);

    // populate the hatId and wearer arrays
    uint256[] memory hatIds = new uint256[](_wearerCount);
    address[] memory wearers = new address[](_wearerCount);

    for (uint256 i; i < _wearerCount; ++i) {
      hatIds[i] = _hatId;
      wearers[i] = address(uint160(i));
    }

    // construct the expected HatMintData struct manually
    HatMintData memory expectedData = HatMintData({ hatIds: hatIds, wearers: wearers });

    // construct the HatMintData struct via our contract
    HatMintData memory testData = harness.constructHatMintData(_hatId, wearers);

    // they two structs should be the same
    assertEq(keccak256(abi.encode(testData)), keccak256(abi.encode(expectedData)));
  }

  function testFuzz_mintHats(uint256 _hatCount, uint256 _wearerCountMin, uint256 _wearerCountMax) public {
    _hatCount = bound(_hatCount, 1, 5);
    _wearerCountMin = bound(_wearerCountMin, 1, 20);
    _wearerCountMax = bound(_wearerCountMax, _wearerCountMin, 20);

    // mint a top hat
    uint256 topHatId = hats.mintTopHat(address(harness), topHatTemplate.details, topHatTemplate.imageURI);

    // initiate the hat minting arrays
    uint256[] memory hatsToMint = new uint256[](_hatCount);
    HatMintData[] memory hatMintDatas = new HatMintData[](_hatCount);

    // populate the hat minting arrays
    for (uint256 i; i < _hatCount; ++i) {
      // create the hat so it is mintable
      vm.prank(address(harness));
      hatsToMint[i] = hats.createHat(topHatId, "", 1000, address(100), address(100), true, "");

      // select a ~random wearer count for this hat between the min and max
      uint256 wearerCount =
        uint256(keccak256(abi.encodePacked(i))) % (_wearerCountMax - _wearerCountMin + 1) + _wearerCountMin;

      // populate the wearer array for this hat
      address[] memory wearers = new address[](wearerCount);
      for (uint256 j; j < wearerCount; ++j) {
        // pull from our test accounts
        wearers[j] = accounts[j];
      }

      // construct the HatMintData struct
      hatMintDatas[i] = harness.constructHatMintData(hatsToMint[i], wearers);
    }

    // mint the hats
    harness.mintHats(hatMintDatas);

    // assert that the hats were minted correctly
    for (uint256 i; i < _hatCount; ++i) {
      for (uint256 j; j < hatMintDatas[i].wearers.length; ++j) {
        assertTrue(hats.isWearerOfHat(hatMintDatas[i].wearers[j], hatMintDatas[i].hatIds[j]));
      }
    }
  }
}

contract DeployTreeAndPrepareHatsFarcasterDelegator is HatsFarcasterBundlerTest {
  address org = makeAddr("org");
  address admin1 = makeAddr("admin1");
  address admin2 = makeAddr("admin2");
  address caster1 = makeAddr("caster1");
  address caster2 = makeAddr("caster2");
  address caster3 = makeAddr("caster3");
  address[] admins = [admin1, admin2];
  address[] casters = [caster1, caster2, caster3];
  uint256 saltNonce = 1;
  uint256 fid = 7;

  function test_happy() public {
    (uint256[] memory hatIds, address delegatorInstance) = bundler.deployTreeAndPrepareHatsFarcasterDelegator(
      org, admins, casters, factory, delegatorImplementation, saltNonce, fid
    );

    // the org should be wearing the top hat
    assertTrue(hats.isWearerOfHat(org, hatIds[0]));
    // the bundler should not be wearing the admin or caster hats
    assertFalse(hats.isWearerOfHat(address(bundler), hatIds[2]));
    assertFalse(hats.isWearerOfHat(address(bundler), hatIds[3]));

    // the admins should be wearing the admin hats
    for (uint256 i; i < admins.length; ++i) {
      assertTrue(hats.isWearerOfHat(admins[i], hatIds[2]));
    }
    // the casters should be wearing the caster hats
    for (uint256 i; i < casters.length; ++i) {
      assertTrue(hats.isWearerOfHat(casters[i], hatIds[3]));
    }

    // the fid should be receivable by the delegator instance
    assertTrue(FarcasterDelegatorLike(delegatorInstance).receivable(fid));
  }

  function test_noAdmins() public {
    admins = new address[](0);
    vm.expectRevert(abi.encodeWithSelector(HatsFarcasterBundler.NoAdmins.selector));
    bundler.deployTreeAndPrepareHatsFarcasterDelegator(
      org, admins, casters, factory, delegatorImplementation, saltNonce, fid
    );
  }

  function test_noCasters() public {
    casters = new address[](0);
    vm.expectRevert(abi.encodeWithSelector(HatsFarcasterBundler.NoCasters.selector));
    bundler.deployTreeAndPrepareHatsFarcasterDelegator(
      org, admins, casters, factory, delegatorImplementation, saltNonce, fid
    );
  }
}

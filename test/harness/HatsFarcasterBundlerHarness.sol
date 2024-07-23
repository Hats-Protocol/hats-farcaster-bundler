// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // comment out before deploy

import {
  HatsFarcasterBundler,
  HatsModuleFactory,
  IHats,
  HatTemplate,
  FarcasterContracts,
  HatMintData
} from "../../src/HatsFarcasterBundler.sol";

contract HatsFarcasterBundlerHarness is HatsFarcasterBundler {
  constructor(
    string memory _version,
    IHats _hats,
    HatTemplate[] memory _treeTemplate,
    FarcasterContracts memory _farcasterContracts
  ) HatsFarcasterBundler(_version, _hats, _treeTemplate, _farcasterContracts) { }

  /**
   * @dev Creates a new hats tree from the hat templates
   * @param _casterEligibility The eligibility module to use for the caster hat
   * @return The hat ids of the created hats
   */
  function createHatsTree(address _casterEligibility) public returns (uint256[] memory) {
    return _createHatsTree(_casterEligibility);
  }

  /**
   * @dev Mints the hats to the wearers in the {_hatMintDatas} array
   * @param _hatMintDatas The hat mint data to pass to the batch mint function
   */
  function mintHats(HatMintData[] memory _hatMintDatas) public {
    _mintHats(_hatMintDatas);
  }

  /**
   * @dev Constructs the hat mint data to pass to the batch mint function
   * @param _hatId The hat id to mint to each of the wearers
   * @param _hatWearers The hat wearers to mint the hat to
   * @return hatMintData The hat mint data
   */
  function constructHatMintData(uint256 _hatId, address[] memory _hatWearers)
    public
    pure
    returns (HatMintData memory hatMintData)
  {
    return _constructHatMintData(_hatId, _hatWearers);
  }

  /**
   * @dev Creates a new HatsFarcasterDelegator instance
   * @param _factory The HatsModuleFactory to use to deploy the HatsFarcasterDelegator instance
   * @param _hatsFarcasterDelegatorImplementation The implementation to use to deploy the HatsFarcasterDelegator
   * instance
   * @param _adminHat The hat id of the owner hat
   * @param _casterHat The hat id of the caster hat
   * @param _saltNonce The salt nonce to use for the HatsFarcasterDelegator instance
   * @return The address of the created HatsFarcasterDelegator instance
   */
  function createHatsFarcasterDelegator(
    HatsModuleFactory _factory,
    address _hatsFarcasterDelegatorImplementation,
    uint256 _adminHat,
    uint256 _casterHat,
    uint256 _saltNonce
  ) public returns (address) {
    return
      _createHatsFarcasterDelegator(_factory, _hatsFarcasterDelegatorImplementation, _adminHat, _casterHat, _saltNonce);
  }

  /**
   * @dev Constructs the other immutable args for the HatsFarcasterDelegator instance deployment
   * @param _adminHat The hat id of the owner hat
   * @return The other immutable args
   */
  function getHatsFarcasterDelegatorOtherImmutableArgs(uint256 _adminHat) public view returns (bytes memory) {
    return _getHatsFarcasterDelegatorOtherImmutableArgs(_adminHat);
  }

  /**
   * @dev Predicts the hat ids of the owner and caster hats based on the next available top hat id and the
   * {treeTemplate} structure
   * @return adminHatId The hat id of the owner hat
   * @return casterHatId The hat id of the caster hat
   */
  function predictAdminAndCasterHatIds() public view returns (uint256 adminHatId, uint256 casterHatId) {
    return _predictAdminAndCasterHatIds();
  }
}

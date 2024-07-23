// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/Test.sol"; // comment out before deploy
import { IHats as HatsLike } from "../lib/hats-protocol/src/Interfaces/IHats.sol";
import { HatsModuleFactory } from "../lib/hats-module/src/HatsModuleFactory.sol";

interface FarcasterDelegatorLike {
  function prepareToReceive(uint256 _fid) external;
  function receivable(uint256 _fid) external view returns (bool);
}

interface IHats is HatsLike {
  function lastTopHatId() external view returns (uint32);
}

/*//////////////////////////////////////////////////////////////
                            DATA MODELS
//////////////////////////////////////////////////////////////*/

struct HatTemplate {
  address eligibility;
  uint32 maxSupply;
  address toggle;
  bool mutable_;
  string details;
  string imageURI;
}

struct FarcasterContracts {
  address IdGateway;
  address idRegistry;
  address keyGateway;
  address keyRegistry;
  address signedKeyRequestValidator;
}

/**
 * @notice The arguments to pass to a batch mint call to mint a single hat to multiple wearers
 * @dev The arrays must be the same length
 * @param hatIds The id of the hat to mint, repeated for each wearer
 * @param wearers The addresses to mint the hat to
 */
struct HatMintData {
  uint256[] hatIds;
  address[] wearers;
}

contract HatsFarcasterBundler {
  /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

  error IncorrectHatIdPrediction();
  error NoAdmins();
  error NoCasters();

  /*//////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  /// @notice The Hats Protocol contract address
  IHats public immutable HATS;

  /// @notice The mask for the owner hat id corresponding to the hat templates structure
  uint256 internal constant ADMIN_HAT_MASK = 0x0000000000010001000000000000000000000000000000000000000000000000;

  /// @notice The mask for the caster hat id corresponding to the hat templates structure
  uint256 internal constant CASTER_HAT_MASK = 0x0000000000010001000100000000000000000000000000000000000000000000;

  /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  /// @notice The semver version of this contract
  string public version;

  HatTemplate public topHatTemplate; // hat x
  HatTemplate public autonomousAdminHatTemplate; // hat x.1
  HatTemplate public adminHatTemplate; // hat x.1.1
  HatTemplate public casterHatTemplate; // hat x.1.1.1

  /// @notice The Farcaster protocol contracts to use when deploying a HatsFarcasterDelegator instance
  FarcasterContracts public farcasterContracts;

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  constructor(
    string memory _version,
    IHats _hats,
    HatTemplate[] memory _treeTemplate,
    FarcasterContracts memory _farcasterContracts
  ) {
    version = _version;
    HATS = _hats;
    farcasterContracts = _farcasterContracts;

    topHatTemplate = _treeTemplate[0];
    autonomousAdminHatTemplate = _treeTemplate[1];
    adminHatTemplate = _treeTemplate[2];
    casterHatTemplate = _treeTemplate[3];
  }

  /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploy a templated hats tree and a HatsFarcasterDelegator instance, and prepare the delegator instance to
   * receive a
   * fid. The first admin will be set as the eligibility module of the caster hat.
   * @param _superAdmin The address to transfer the top hat to
   * @param _admins The addresses to mint the admin hats to; must have at least one admin
   * @param _casters The addresses to mint the caster hats to; must have at least one caster
   * @param _factory The HatsModuleFactory to use to deploy the HatsFarcasterDelegator instance
   * @param _hatsFarcasterDelegatorImplementation The implementation to use to deploy the HatsFarcasterDelegator
   * instance
   * @param _saltNonce The salt nonce to use for the HatsFarcasterDelegator instance
   * @param _fid The fid to prepare the delegator instance to receive
   */
  function deployTreeAndPrepareHatsFarcasterDelegator(
    address _superAdmin,
    address[] memory _admins,
    address[] memory _casters,
    HatsModuleFactory _factory,
    address _hatsFarcasterDelegatorImplementation,
    uint256 _saltNonce,
    uint256 _fid
  ) external returns (uint256[] memory hatIds, address hatsFarcasterDelegatorInstance) {
    // --- 0. check for no admins or casters -----------------------
    if (_admins.length == 0) revert NoAdmins();
    if (_casters.length == 0) revert NoCasters();

    // --- 1. deploy the HatsFarcasterDelegator instance -----------

    // predict the owner and caster hat ids
    (uint256 adminHatId, uint256 casterHatId) = _predictAdminAndCasterHatIds();

    // create the instance
    hatsFarcasterDelegatorInstance = _createHatsFarcasterDelegator(
      _factory, _hatsFarcasterDelegatorImplementation, adminHatId, casterHatId, _saltNonce
    );

    // --- 2. create the hats tree ---------------------------------

    // create the tree, with this contract temporarily wearing the top hat and the first admin hat wearer as the
    // eligibility module for the caster hat
    hatIds = _createHatsTree(_admins[0]);

    // assert that the predicted caster hat id matches actual
    if (hatIds[3] != casterHatId) revert IncorrectHatIdPrediction();

    // --- 3. prepare the delegator instance to receive the fid ----

    // authorize this contract to call prepareToReceive by minting it the adminHat
    HATS.mintHat(hatIds[2], address(this));

    // call prepareToReceive on the delegator instance
    FarcasterDelegatorLike(hatsFarcasterDelegatorInstance).prepareToReceive(_fid);

    // renounce the adminHat
    HATS.renounceHat(hatIds[2]);

    // --- 4. mint the admin and caster hats ----------------------------------------

    // construct the batch mint hat data to mint the admin and caster hats
    HatMintData[] memory hatMintDatas = new HatMintData[](2);
    hatMintDatas[0] = _constructHatMintData(hatIds[2], _admins); // admin hat
    hatMintDatas[1] = _constructHatMintData(hatIds[3], _casters); // caster hat

    // do the mint
    _mintHats(hatMintDatas);

    // --- 5. transfer the top hat to the desired top hat wearer ---
    HATS.transferHat(hatIds[0], address(this), _superAdmin);
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Predicts the hat ids of the owner and caster hats based on the next available top hat id and the
   * hat templates structure
   * @return adminHatId The hat id of the owner hat
   * @return casterHatId The hat id of the caster hat
   */
  function _predictAdminAndCasterHatIds() internal view returns (uint256 adminHatId, uint256 casterHatId) {
    uint256 topHatId = (uint256(HATS.lastTopHatId()) + 1) << 224;

    adminHatId = topHatId | ADMIN_HAT_MASK;
    casterHatId = topHatId | CASTER_HAT_MASK;
  }

  /**
   * @dev Constructs the other immutable args for the HatsFarcasterDelegator instance deployment
   * @param _adminHat The hat id of the owner hat
   * @return The other immutable args
   */
  function _getHatsFarcasterDelegatorOtherImmutableArgs(uint256 _adminHat) internal view returns (bytes memory) {
    return abi.encodePacked(
      _adminHat,
      farcasterContracts.IdGateway,
      farcasterContracts.idRegistry,
      farcasterContracts.keyGateway,
      farcasterContracts.keyRegistry,
      farcasterContracts.signedKeyRequestValidator
    );
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
  function _createHatsFarcasterDelegator(
    HatsModuleFactory _factory,
    address _hatsFarcasterDelegatorImplementation,
    uint256 _adminHat,
    uint256 _casterHat,
    uint256 _saltNonce
  ) internal returns (address) {
    return _factory.createHatsModule(
      _hatsFarcasterDelegatorImplementation,
      _casterHat,
      _getHatsFarcasterDelegatorOtherImmutableArgs(_adminHat),
      abi.encode(), // no init data for this module
      _saltNonce
    );
  }

  /**
   * @dev Creates a new hats tree from the hats templates
   * @param _casterEligibility The eligibility module to use for the caster hat
   * @return The hat ids of the created hats
   */
  function _createHatsTree(address _casterEligibility) internal returns (uint256[] memory) {
    // create an array to store the hat ids
    uint256[] memory hatIds = new uint256[](4);

    // create and mint the top hat to this contract
    hatIds[0] = HATS.mintTopHat(address(this), topHatTemplate.details, topHatTemplate.imageURI);

    // create the autonomous admin hat
    hatIds[1] = HATS.createHat(
      hatIds[0],
      autonomousAdminHatTemplate.details,
      autonomousAdminHatTemplate.maxSupply,
      autonomousAdminHatTemplate.eligibility,
      autonomousAdminHatTemplate.toggle,
      autonomousAdminHatTemplate.mutable_,
      autonomousAdminHatTemplate.imageURI
    );

    // create the admin hat
    hatIds[2] = HATS.createHat(
      hatIds[1],
      adminHatTemplate.details,
      adminHatTemplate.maxSupply,
      adminHatTemplate.eligibility,
      adminHatTemplate.toggle,
      adminHatTemplate.mutable_,
      adminHatTemplate.imageURI
    );

    // create the caster hat
    hatIds[3] = HATS.createHat(
      hatIds[2],
      casterHatTemplate.details,
      casterHatTemplate.maxSupply,
      _casterEligibility, // override the template
      casterHatTemplate.toggle,
      casterHatTemplate.mutable_,
      casterHatTemplate.imageURI
    );

    return hatIds;
  }

  /**
   * @dev Constructs the hat mint data to pass to the batch mint function
   * @param _hatId The hat id to mint to each of the wearers
   * @param _hatWearers The hat wearers to mint the hat to
   * @return hatMintData The hat mint data
   */
  function _constructHatMintData(uint256 _hatId, address[] memory _hatWearers)
    internal
    pure
    returns (HatMintData memory hatMintData)
  {
    uint256 length = _hatWearers.length;
    hatMintData.hatIds = new uint256[](length);

    for (uint256 i; i < length; ++i) {
      hatMintData.hatIds[i] = _hatId;
    }

    hatMintData.wearers = _hatWearers;
  }

  /**
   * @dev Mints the hats to the wearers in the {_hatMintDatas} array
   * @param _hatMintDatas The hat mint data to pass to the batch mint function
   */
  function _mintHats(HatMintData[] memory _hatMintDatas) internal {
    for (uint256 i; i < _hatMintDatas.length; ++i) {
      HATS.batchMintHats(_hatMintDatas[i].hatIds, _hatMintDatas[i].wearers);
    }
  }
}

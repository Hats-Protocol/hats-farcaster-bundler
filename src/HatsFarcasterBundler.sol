// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // comment out before deploy
import { IHats as HatsLike } from "../lib/hats-protocol/src/Interfaces/IHats.sol";
import { HatsModuleFactory } from "../lib/hats-module/src/HatsModuleFactory.sol";

interface FarcasterDelegatorLike {
  function prepareToReceive(uint256 _fid) external;
}

interface IHats is HatsLike {
  function lastTopHatId() external view returns (uint32);
}

contract HatsFarcasterBundler {
  /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

  error IncorrectHatIdPrediction();
  error InvalidArrayLength();

  /*//////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////
                            DATA MODELS
  //////////////////////////////////////////////////////////////*/

  /// @notice modified from Hats.sol for original definition
  struct Hat {
    address eligibility;
    uint32 maxSupply;
    uint32 supply;
    uint16 lastHatId;
    address toggle;
    bool mutable_;
    string details;
    string imageURI;
  }

  struct FarcasterContracts {
    address _IdGateway;
    address _idRegistry;
    address _keyGateway;
    address _keyRegistry;
    address _signedKeyRequestValidator;
  }

  struct HatWearers {
    address[] wearers;
  }

  /**
   * @notice The arguments to pass to a batch mint call to mint a single hat to multiple wearers
   * @dev The arrays must be the same length
   * @param wearers The addresses to mint the hat to
   */
  struct HatMintData {
    uint256[] hatIds;
    address[] wearers;
  }

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  /// @notice The Hats Protocol contract address
  IHats public immutable HATS;

  /// @notice The mask for the owner hat id corresponding to the {hatTreeTemplate} structure
  uint256 internal constant OWNER_HAT_MASK = 0x0000000000010001000000000000000000000000000000000000000000000000;

  /// @notice The mask for the caster hat id corresponding to the {hatTreeTemplate} structure
  uint256 internal constant CASTER_HAT_MASK = 0x0000000000010001000100000000000000000000000000000000000000000000;

  /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  /// @notice The semver version of this contract
  string public version;

  /**
   * @notice A simple hats tree template that takes the following format:
   * [0] = x -> topHat
   * [1] = x.1 -> autonomousAdminHat
   * [2] = x.1.1 -> ownerHat
   * [3] = x.1.1.1 -> casterHat
   */
  Hat[] public hatTreeTemplate;

  /// @notice The Farcaster protocol contracts to use when deploying a HatsFarcasterDelegator instance
  FarcasterContracts public farcasterContracts;

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  constructor(
    string memory _version,
    IHats _hats,
    Hat[] memory _hatTreeTemplate,
    FarcasterContracts memory _farcasterContracts
  ) {
    version = _version;
    HATS = _hats;
    farcasterContracts = _farcasterContracts;

    hatTreeTemplate[0] = _hatTreeTemplate[0];
    hatTreeTemplate[1] = _hatTreeTemplate[1];
    hatTreeTemplate[2] = _hatTreeTemplate[2];
    hatTreeTemplate[3] = _hatTreeTemplate[3];
  }

  /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploy a hats tree and the HatsFarcasterDelegator instance, and prepare the delegator instance to receive a
   * fid
   * @param _topHatWearer The address to transfer the top hat to
   * @param _childHatWearers The addresses to mint the child hats to
   * @param _factory The HatsModuleFactory to use to deploy the HatsFarcasterDelegator instance
   * @param _hatsFarcasterDelegatorImplementation The implementation to use to deploy the HatsFarcasterDelegator
   * instance
   * @param _saltNonce The salt nonce to use for the HatsFarcasterDelegator instance
   * @param _fid The fid to prepare the delegator instance to receive
   */
  function deployTreeAndPrepareHatsFarcasterDelegator(
    address _topHatWearer,
    HatWearers[] memory _childHatWearers,
    HatsModuleFactory _factory,
    address _hatsFarcasterDelegatorImplementation,
    uint256 _saltNonce,
    uint256 _fid
  ) external returns (uint256[] memory hatIds, address hatsFarcasterDelegatorInstance) {
    // --- 1. deploy the HatsFarcasterDelegator instance -----------

    // predict the owner and caster hat ids
    (uint256 ownerHatId, uint256 casterHatId) = _predictOwnerAndCasterHatIds();

    // create the instance
    hatsFarcasterDelegatorInstance = _createHatsFarcasterDelegator(
      _factory, _hatsFarcasterDelegatorImplementation, ownerHatId, casterHatId, _saltNonce
    );

    // --- 2. create the hats tree ---------------------------------

    // create the tree, with this contract temporarily wearing the top hat
    hatIds = _createHatsTree(hatsFarcasterDelegatorInstance);

    // assert that the predicted caster hat id matches actual
    if (hatIds[3] != casterHatId) revert IncorrectHatIdPrediction();

    // --- 3. prepare the delegator instance to receive the fid ----

    // authorize this contract to call prepareToReceive by minting it the ownerHat
    HATS.mintHat(hatIds[2], address(this));

    // call prepareToReceive on the delegator instance
    FarcasterDelegatorLike(hatsFarcasterDelegatorInstance).prepareToReceive(_fid);

    // renounce the ownerHat
    HATS.renounceHat(hatIds[2]);

    // --- 4. mint the hats ----------------------------------------

    // assert that the hat wearers array length is 4
    if (_childHatWearers.length != 4) revert InvalidArrayLength();

    // construct the batch mint hat data to mint the child hats
    HatMintData[] memory hatMintDatas = new HatMintData[](3);
    hatMintDatas[0] = _constructHatMintData(hatIds[1], _childHatWearers[1]);
    hatMintDatas[1] = _constructHatMintData(hatIds[2], _childHatWearers[2]);
    hatMintDatas[2] = _constructHatMintData(hatIds[3], _childHatWearers[3]);

    // do the mint
    _mintHats(hatMintDatas);

    // --- 5. transfer the top hat to the desired top hat wearer ---
    HATS.transferHat(hatIds[0], address(this), _topHatWearer);
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Creates a new hats tree from the {hatTreeTemplate}, setting the HatsFarcasterDelegator instance as the
   * casterHat's eligibility module
   * @param _hatsFarcasterDelegatorInstance The address of the HatsFarcasterDelegator instance to set as the casterHat's
   * eligibility module
   * @return The hat ids of the created hats
   */
  function _createHatsTree(address _hatsFarcasterDelegatorInstance) internal returns (uint256[] memory) {
    // load the tree template into memory
    Hat[] memory template = hatTreeTemplate;

    // create an array to store the hat ids
    uint256[] memory hatIds = new uint256[](4);

    // create and mint the top hat to this contract
    hatIds[0] = HATS.mintTopHat(address(this), template[0].details, template[0].imageURI);

    // create the autonomous admin hat
    hatIds[1] = HATS.createHat(
      hatIds[0],
      template[1].details,
      template[1].maxSupply,
      template[1].eligibility,
      template[1].toggle,
      template[1].mutable_,
      template[1].imageURI
    );

    // create the owner hat
    hatIds[2] = HATS.createHat(
      hatIds[1],
      template[2].details,
      template[2].maxSupply,
      template[2].eligibility,
      template[2].toggle,
      template[2].mutable_,
      template[2].imageURI
    );

    // create the caster hat, with the hats farcaster delegator instance as the eligibility module
    hatIds[3] = HATS.createHat(
      hatIds[2],
      template[3].details,
      template[3].maxSupply,
      _hatsFarcasterDelegatorInstance,
      template[3].toggle,
      template[3].mutable_,
      template[3].imageURI
    );

    return hatIds;
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

  /**
   * @dev Constructs the hat mint data to pass to the batch mint function
   * @param _hatId The hat id to mint to each of the wearers
   * @param _hatWearers The hat wearers to mint the hat to
   * @return hatMintData The hat mint data
   */
  function _constructHatMintData(uint256 _hatId, HatWearers memory _hatWearers)
    internal
    pure
    returns (HatMintData memory hatMintData)
  {
    for (uint256 i; i < _hatWearers.wearers.length; ++i) {
      hatMintData.hatIds[i] = _hatId;
    }

    hatMintData.wearers = _hatWearers.wearers;
  }

  /**
   * @dev Creates a new HatsFarcasterDelegator instance
   * @param _factory The HatsModuleFactory to use to deploy the HatsFarcasterDelegator instance
   * @param _hatsFarcasterDelegatorImplementation The implementation to use to deploy the HatsFarcasterDelegator
   * instance
   * @param _ownerHat The hat id of the owner hat
   * @param _casterHat The hat id of the caster hat
   * @param _saltNonce The salt nonce to use for the HatsFarcasterDelegator instance
   * @return The address of the created HatsFarcasterDelegator instance
   */
  function _createHatsFarcasterDelegator(
    HatsModuleFactory _factory,
    address _hatsFarcasterDelegatorImplementation,
    uint256 _ownerHat,
    uint256 _casterHat,
    uint256 _saltNonce
  ) internal returns (address) {
    return _factory.createHatsModule(
      _hatsFarcasterDelegatorImplementation,
      _casterHat,
      _getHatsFarcasterDelegatorOtherImmutableArgs(_ownerHat),
      abi.encode(), // no init data for this module
      _saltNonce
    );
  }

  // function _predictHatsFarcasterDelegatorAddress(
  //   HatsModuleFactory _factory,
  //   address _hatsFarcasterDelegatorImplementation,
  //   uint256 _casterHat,
  //   uint256 _ownerHat,
  //   uint256 _saltNonce
  // ) internal view returns (address) {
  //   return _factory.getHatsModuleAddress(
  //     _hatsFarcasterDelegatorImplementation,
  //     _casterHat,
  //     _getHatsFarcasterDelegatorOtherImmutableArgs(_ownerHat),
  //     _saltNonce
  //   );
  // }

  /**
   * @dev Constructs the other immutable args for the HatsFarcasterDelegator instance deployment
   * @param _ownerHat The hat id of the owner hat
   * @return The other immutable args
   */
  function _getHatsFarcasterDelegatorOtherImmutableArgs(uint256 _ownerHat) internal view returns (bytes memory) {
    return abi.encodePacked(
      _ownerHat,
      farcasterContracts._IdGateway,
      farcasterContracts._idRegistry,
      farcasterContracts._keyGateway,
      farcasterContracts._keyRegistry,
      farcasterContracts._signedKeyRequestValidator
    );
  }

  /**
   * @dev Predicts the hat ids of the owner and caster hats based on the next available top hat id and the
   * {hatTreeTemplate} structure
   * @return ownerHatId The hat id of the owner hat
   * @return casterHatId The hat id of the caster hat
   */
  function _predictOwnerAndCasterHatIds() internal view returns (uint256 ownerHatId, uint256 casterHatId) {
    uint256 topHatId = (HATS.lastTopHatId() + 1) << 224;

    ownerHatId = topHatId | OWNER_HAT_MASK;
    casterHatId = topHatId | CASTER_HAT_MASK;
  }
}

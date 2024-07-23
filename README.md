# HatsFarcasterBundler

A utility contract for creating a quick and simple configuration for a shared Farcaster account. In a single transaction, this contract will...

1. Deploy a simple Hats tree according to a predetermined template
2. Deploy a HatsFarcasterDelegator instance
3. Prepare the delegator instance to receive FID of the Farcaster account to be shared

## Overview and Usage

Use this contract by calling `deployTreeAndPrepareHatsFarcasterDelegator` with the following parameters:

- `superAdmin`: The address to mint the top hat to
- `admins`: The addresses to mint the admin hats to (at least 1)
- `casters`: The addresses to mint the caster hats to (at least 1)
- `factory`: The HatsModuleFactory address, typically the most recent deployment of [HatsModuleFactory](https://github.com/hats-protocol/hats-module/releases)
- `delegatorImplementation`: The HatsFarcasterDelegator implementation address, typically the most recent version of [HatsFarcasterDelegator](https://github.com/hats-protocol/farcaster-delegator/releases)
- `saltNonce`: A salt nonce to use for the HatsFarcasterDelegator deployment
- `fid`: The Farcaster FID to be shared

### Hats Tree Template

This contract defines a simple Hats tree with the below structure of four hats.

0. Hat x — The top hat, worn by the super admin (typically a DAO, multisig, etc)
1. Hat x.1 — The autonomous admin hat, unworn to start and meant as a placeholder for future flexibility
2. Hat x.1.1 — The admin hat, worn by the specified admins
3. Hat x.1.1.1 — The caster hat, worn by the specified casters

The properties of these hats — collectively known as the `treeTemplate` — are defined on contract deployment as a constructor argument. The template cannot be changed after deployment.

#### Hat Template

The `treeTemplate` is an array of `HatTemplate`s, each holding the properties of the hat at that index in the array (see the numbered list above). The configurable properties of each hat are as follows:

```solidity
struct HatTemplate {
  address eligibility; // The address of the eligibility module for the hat
  uint32 maxSupply; // The maximum number of wearers of the hat
  address toggle; // The address of the toggle module for the hat
  bool mutable_; // Whether the hat is mutable
  string details; // The details of the hat, typically as an IPFS CID
  string imageURI; // The URI of the hat's image, typically as an IPFS CID
}
```

>**Note**
When using this contract to deploy a new tree, the `eligibility` module for the caster hat will always be set as the first address in the `admins` array, overriding the template if necessary.
>


## Development

This repo uses Foundry for development and testing. To get started:

1. Fork the project
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
3. To install dependencies, run `forge install`
4. To compile the contracts, run `forge build`
5. To test, run `forge test`

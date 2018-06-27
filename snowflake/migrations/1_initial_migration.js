const snowflake = artifacts.require('./Snowflake.sol')

const SafeMath = artifacts.require('./libraries/SafeMath.sol')
const uint8Set = artifacts.require('./libraries/uint8Set.sol')
const stringSet = artifacts.require('./libraries/stringSet.sol')
const addressSet = artifacts.require('./libraries/addressSet.sol')
const bytes32Set = artifacts.require('./libraries/bytes32Set.sol')

// const KYC = artifacts.require('./resolvers/HydroKYC.sol')
// const Reputation = artifacts.require('./resolvers/HydroReputation.sol')
const AddressOwnership = artifacts.require('./resolvers/AddressOwnership.sol')

module.exports = function (deployer) {
  // deploy libraries
  deployer.deploy(SafeMath)
  deployer.deploy(uint8Set)
  deployer.deploy(stringSet)
  deployer.deploy(addressSet)
  deployer.deploy(bytes32Set)

  // deploy snowflake
  deployer.link(SafeMath, snowflake)
  deployer.link(uint8Set, snowflake)
  deployer.link(stringSet, snowflake)
  deployer.link(addressSet, snowflake)
  deployer.deploy(snowflake)

  // deploy resolvers
  // deployer.link(bytes32Set, KYC)
  // deployer.link(addressSet, KYC)
  // deployer.deploy(KYC)

  // deployer.deploy(Reputation)

  deployer.link(addressSet, AddressOwnership)
  deployer.deploy(AddressOwnership)
}

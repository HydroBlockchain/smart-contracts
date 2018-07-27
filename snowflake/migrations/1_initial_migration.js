const snowflake = artifacts.require('./Snowflake.sol')

const SafeMath = artifacts.require('./libraries/SafeMath.sol')
const addressSet = artifacts.require('./libraries/addressSet.sol')

// const KYC = artifacts.require('./resolvers/HydroKYC.sol')
// const Reputation = artifacts.require('./resolvers/HydroReputation.sol')
// const addressOwnership = artifacts.require('./resolvers/AddressOwnership.sol')

module.exports = function (deployer) {
  // deploy libraries
  deployer.deploy(SafeMath)
  deployer.deploy(addressSet)

  // deploy snowflake
  deployer.link(SafeMath, snowflake)
  deployer.link(addressSet, snowflake)
  deployer.deploy(snowflake)

  // deploy resolvers
  // deployer.link(bytes32Set, KYC)
  // deployer.link(addressSet, KYC)
  // deployer.deploy(KYC)

  // deployer.deploy(Reputation)

  // deployer.link(addressSet, addressOwnership)
  // deployer.deploy(addressOwnership)
}

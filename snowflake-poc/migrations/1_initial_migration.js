const snowflake = artifacts.require('./Snowflake.sol')

const SafeMath = artifacts.require('./libraries/SafeMath.sol')
const uint8Set = artifacts.require('./libraries/uint8Set.sol')
const stringSet = artifacts.require('./libraries/stringSet.sol')
const addressSet = artifacts.require('./libraries/addressSet.sol')
const bytes32Set = artifacts.require('./libraries/bytes32Set.sol')

const AddressOwnership = artifacts.require('./resolvers/AddressOwnership.sol')
const HydroKYC = artifacts.require('./resolvers/HydroKYC.sol')

module.exports = function (deployer) {
  deployer.deploy(SafeMath)
  deployer.deploy(uint8Set)
  deployer.deploy(stringSet)
  deployer.deploy(addressSet)
  deployer.deploy(bytes32Set)

  deployer.link(SafeMath, snowflake)
  deployer.link(uint8Set, snowflake)
  deployer.link(stringSet, snowflake)
  deployer.link(addressSet, snowflake)

  deployer.deploy(snowflake)

  deployer.deploy(addressSet)
  deployer.link(addressSet, AddressOwnership)

  deployer.deploy(AddressOwnership)

  deployer.link(addressSet, HydroKYC)
  deployer.link(bytes32Set, HydroKYC)
}

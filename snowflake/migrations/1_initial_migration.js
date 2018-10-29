const AddressSet = artifacts.require('./_testing/AddressSet/AddressSet.sol')
const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')

const SafeMath = artifacts.require('./libraries/SafeMath.sol')
const Snowflake = artifacts.require('./Snowflake.sol')

const StringUtils = artifacts.require('./resolvers/ClientRaindrop/StringUtils.sol')
const ClientRaindrop = artifacts.require('./resolvers/ClientRaindrop/ClientRaindrop.sol')

module.exports = async function (deployer) {
  deployer.deploy(AddressSet)
  deployer.link(AddressSet, IdentityRegistry)

  deployer.deploy(SafeMath)
  deployer.link(SafeMath, Snowflake)

  deployer.deploy(StringUtils)
  deployer.link(StringUtils, ClientRaindrop)
}

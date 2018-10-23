const Snowflake = artifacts.require('./Snowflake.sol')
const AddressSet = artifacts.require('./_testing/AddressSet/AddressSet.sol')
const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')

// const Status = artifacts.require('./resolvers/Status.sol')

const SafeMath = artifacts.require('./libraries/SafeMath.sol')

module.exports = async function (deployer) {
  deployer.deploy(SafeMath)
  deployer.link(SafeMath, Snowflake)

  deployer.deploy(AddressSet)
  deployer.link(AddressSet, IdentityRegistry)
  // await deployer.deploy(IdentityRegistry)
  // await deployer.deploy(Snowflake)
  //
  // const snowflake = await Snowflake.deployed()

  // deploy status
  // await deployer.deploy(Status, snowflake.address)
}

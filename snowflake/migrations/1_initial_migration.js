const snowflake = artifacts.require('./Snowflake.sol')
const status = artifacts.require('./resolvers/Status.sol')

const SafeMath = artifacts.require('./libraries/SafeMath.sol')
const addressSet = artifacts.require('./libraries/addressSet.sol')

module.exports = function (deployer) {
  deployer.deploy(status)

  // // deploy libraries
  // deployer.deploy(SafeMath)
  // deployer.deploy(addressSet)

  // // deploy snowflake
  // deployer.link(SafeMath, snowflake)
  // deployer.link(addressSet, snowflake)
  // deployer.deploy(snowflake)
}

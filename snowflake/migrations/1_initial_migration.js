const snowflake = artifacts.require('./Snowflake.sol')

const SafeMath = artifacts.require('./libraries/SafeMath.sol')
const addressSet = artifacts.require('./libraries/addressSet.sol')

module.exports = function (deployer) {
  // deploy libraries
  deployer.deploy(SafeMath)
  deployer.deploy(addressSet)

  // deploy snowflake
  deployer.link(SafeMath, snowflake)
  deployer.link(addressSet, snowflake)
  deployer.deploy(snowflake)
}

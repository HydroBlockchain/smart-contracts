const snowflake = artifacts.require('./Snowflake.sol')

const stringSet = artifacts.require('./libraries/stringSet.sol')
const bytes32Set = artifacts.require('./libraries/bytes32Set.sol')
const addressSet = artifacts.require('./libraries/addressSet.sol')

module.exports = function (deployer) {
  deployer.deploy(stringSet)
  deployer.deploy(bytes32Set)
  deployer.deploy(addressSet)
  deployer.link(stringSet, snowflake)
  deployer.link(bytes32Set, snowflake)
  deployer.link(addressSet, snowflake)

  deployer.deploy(snowflake)
}

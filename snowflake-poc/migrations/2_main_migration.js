var SnowflakeRegistry = artifacts.require('./SnowflakeRegistry.sol')

module.exports = function (deployer) {
  deployer.deploy(SnowflakeRegistry)
}

var SnowflakeRegistry = artifacts.require('./SnowflakeRegistry.sol')
var SnowflakeEscrow = artifacts.require('./SnowflakeEscrow.sol')

module.exports = function (deployer) {
  deployer.deploy(SnowflakeRegistry)
  deployer.deploy(SnowflakeEscrow)
}

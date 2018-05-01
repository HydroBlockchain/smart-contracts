const SnowflakeEscrow = artifacts.require('./SnowflakeEscrow.sol')

module.exports = function (deployer) {
  deployer.deploy(SnowflakeEscrow)
}

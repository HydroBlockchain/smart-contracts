const escrow = artifacts.require('./SnowflakeEscrow')

module.exports = function (deployer) {
  deployer.deploy(escrow)
}

const escrow = artifacts.require('./SnowflakeEscrow.sol')

module.exports = function (deployer) {
  deployer.deploy(escrow)
}

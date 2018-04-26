var Snowflake = artifacts.require('./Snowflake.sol')

module.exports = function (deployer) {
  deployer.deploy(Snowflake)
}

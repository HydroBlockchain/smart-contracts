const SnowflakeRegistry = artifacts.require('./SnowflakeRegistry.sol')

const bytes32Set = artifacts.require('./libraries/bytes32Set.sol')
const BytesLibrary = artifacts.require('./libraries/BytesLibrary.sol')

module.exports = function (deployer) {
  deployer.deploy(bytes32Set)
  deployer.deploy(BytesLibrary)
  deployer.link(bytes32Set, SnowflakeRegistry)
  deployer.link(BytesLibrary, SnowflakeRegistry)

  deployer.deploy(SnowflakeRegistry)
}

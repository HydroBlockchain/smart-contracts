const registry = artifacts.require('./SnowflakeRegistry')

const bytes32Set = artifacts.require('./libraries/bytes32Set')
const BytesLibrary = artifacts.require('./libraries/BytesLibrary')

module.exports = function (deployer) {
  deployer.deploy(bytes32Set)
  deployer.deploy(BytesLibrary)
  deployer.link(bytes32Set, registry)
  deployer.link(BytesLibrary, registry)

  deployer.deploy(registry)
}

var StringUtils = artifacts.require('./StringUtils.sol')
var ClientRaindrop = artifacts.require('./RaindropClient.sol')

module.exports = function (deployer) {
  deployer.deploy(StringUtils)
  deployer.link(StringUtils, ClientRaindrop)
  deployer.deploy(ClientRaindrop)
}

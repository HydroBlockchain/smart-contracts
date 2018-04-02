var StringUtils = artifacts.require('./StringUtils.sol')
var RaindropClient = artifacts.require('./RaindropClient.sol')

module.exports = function (deployer) {
  deployer.deploy(StringUtils)
  deployer.link(StringUtils, RaindropClient)
  deployer.deploy(RaindropClient)
}

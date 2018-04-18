var RaindropClient = artifacts.require('./RaindropClient.sol')

module.exports = function (deployer) {
  deployer.deploy(RaindropClient)
}

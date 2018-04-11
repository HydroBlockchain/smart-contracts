var StringUtils = artifacts.require('./StringUtils.sol')
var RaindropClient = artifacts.require('./RaindropClient.sol')
var HydroToken = artifacts.require('./HydroToken.sol')
var Ownable = artifacts.require('./zeppelin/ownership/Ownable.sol')
var SafeMath = artifacts.require('./SafeMath.sol')

module.exports = function (deployer) {
  deployer.deploy(StringUtils)
  deployer.link(StringUtils, RaindropClient)
  deployer.deploy(RaindropClient)
  deployer.deploy(Ownable)
  deployer.deploy(SafeMath)
  deployer.link(Ownable, HydroToken)
  deployer.link(SafeMath, HydroToken)
  deployer.deploy(HydroToken)
}

const AddressOwnership = artifacts.require('./resolvers/AddressOwnership.sol')

const addressSet = artifacts.require('./libraries/addressSet.sol')

module.exports = function (deployer) {
  deployer.deploy(addressSet)
  deployer.link(addressSet, AddressOwnership)

  deployer.deploy(AddressOwnership)
}

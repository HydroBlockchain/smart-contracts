const AddressSet = artifacts.require('./_testing/AddressSet/AddressSet.sol')
const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')

const HydroToken = artifacts.require('./_testing/HydroToken.sol')

const SafeMath = artifacts.require('./zeppelin/math/SafeMath.sol')
const Snowflake = artifacts.require('./Snowflake.sol')
const Status = artifacts.require('./resolvers/Status.sol')

const StringUtils = artifacts.require('./resolvers/ClientRaindrop/StringUtils.sol')
const ClientRaindrop = artifacts.require('./resolvers/ClientRaindrop/ClientRaindrop.sol')
const OldClientRaindrop = artifacts.require('./_testing/OldClientRaindrop.sol')

module.exports = async function (deployer) {
  await deployer.deploy(AddressSet)
  deployer.link(AddressSet, IdentityRegistry)

  await deployer.deploy(SafeMath)
  deployer.link(SafeMath, HydroToken)
  deployer.link(SafeMath, Snowflake)

  await deployer.deploy(StringUtils)
  deployer.link(StringUtils, ClientRaindrop)
  deployer.link(StringUtils, OldClientRaindrop)

  // const identityRegistry = await deployer.deploy(IdentityRegistry)
  // const hydroToken = await deployer.deploy(HydroToken)
  const snowflake = await deployer.deploy(Snowflake, '0xDeE6120D632007AC29a720372e943Ae8ED7A783d', '0x4959c7f62051D6b2ed6EaeD3AAeE1F961B145F20')
  // // const oldClientRaindrop = await deployer.deploy(OldClientRaindrop)
  await deployer.deploy(ClientRaindrop, snowflake.address, '0xb29778Cf8abFFF8BF245b9060CD2299ADb358040', 0, 0)
  await deployer.deploy(Status, snowflake.address)
}

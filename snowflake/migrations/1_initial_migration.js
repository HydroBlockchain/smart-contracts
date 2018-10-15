const Snowflake = artifacts.require('./Snowflake.sol')
const Status = artifacts.require('./resolvers/Status.sol')

const SafeMath = artifacts.require('./libraries/SafeMath.sol')
const addressSet = artifacts.require('./libraries/addressSet.sol')

module.exports = async function (deployer) {
  // deploy libraries
  await deployer.deploy(SafeMath)
  await deployer.deploy(addressSet)

  // deploy snowflake
  await deployer.link(SafeMath, Snowflake)
  await deployer.link(addressSet, Snowflake)
  await deployer.deploy(Snowflake)

  const snowflake = await Snowflake.deployed()

  // deploy status
  await deployer.deploy(Status, snowflake.address)
}

const Snowflake = artifacts.require('./Snowflake.sol')
const Status = artifacts.require('./resolvers/Status.sol')

const SafeMath = artifacts.require('./libraries/SafeMath.sol')

module.exports = async function (deployer) {
  deployer.deploy(SafeMath)

  deployer.link(SafeMath, Snowflake)
  await deployer.deploy(Snowflake)

  const snowflake = await Snowflake.deployed()

  // deploy status
  await deployer.deploy(Status, snowflake.address)
}

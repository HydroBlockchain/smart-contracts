const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')
const HydroToken = artifacts.require('./_testing/HydroToken.sol')
const Snowflake = artifacts.require('./Snowflake.sol')
const ClientRaindrop = artifacts.require('./resolvers/ClientRaindrop/ClientRaindrop.sol')

async function initialize (owner, users) {
  const instances = {}

  instances.HydroToken = await HydroToken.new({ from: owner })
  for (let i = 0; i < users.length; i++) {
    await instances.HydroToken.transfer(
      users[i].address,
      web3.utils.toBN(1000).mul(web3.utils.toBN(1e18)),
      { from: owner }
    )
  }

  instances.IdentityRegistry = await IdentityRegistry.new({ from: owner })

  instances.Snowflake = await Snowflake.new(
    instances.IdentityRegistry.address, instances.HydroToken.address, { from: owner }
  )

  instances.ClientRaindrop = await ClientRaindrop.new(instances.Snowflake.address, 0, 0, { from: owner })
  await instances.Snowflake.setClientRaindropAddress(instances.ClientRaindrop.address)

  return instances
}

module.exports = {
  initialize: initialize
}

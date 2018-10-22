const Web3 = require('web3')
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

const IdentityRegistry = artifacts.require('./_testing/IdentityRegistry.sol')
const HydroToken = artifacts.require('./_testing/HydroToken.sol')
const Snowflake = artifacts.require('./Snowflake.sol')
const ClientRaindrop = artifacts.require('./_testing/ClientRaindrop.sol')

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
  let receipt = await web3.eth.getTransactionReceipt(instances.Snowflake.transactionHash)
  assert.isAtMost(receipt.cumulativeGasUsed, 6000000)

  instances.ClientRaindrop = await ClientRaindrop.new(instances.Snowflake.address, 0, 0, { from: owner })
  await instances.Snowflake.setClientRaindropAddress(instances.ClientRaindrop.address)

  return instances
}

module.exports = {
  initialize: initialize
}

const Web3 = require('web3') // 1.0.0-beta.34
const ethUtil = require('ethereumjs-util')
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

const HydroToken = artifacts.require('./_testing/HydroToken.sol')
const ClientRaindrop = artifacts.require('./_testing/ClientRaindrop.sol')

const Snowflake = artifacts.require('./Snowflake.sol')

module.exports.sign = (messageHash, user, method) => {
  return new Promise((resolve, reject) => {
    if (method === 'unprefixed') {
      let signature = ethUtil.ecsign(
        Buffer.from(ethUtil.stripHexPrefix(messageHash), 'hex'), Buffer.from(user.private, 'hex')
      )
      signature.r = ethUtil.bufferToHex(signature.r)
      signature.s = ethUtil.bufferToHex(signature.s)
      signature.v = parseInt(ethUtil.bufferToHex(signature.v))
      resolve(signature)
    } else {
      web3.eth.sign(messageHash, user.public)
        .then(concatenatedSignature => {
          let strippedSignature = ethUtil.stripHexPrefix(concatenatedSignature)
          let signature = {
            r: ethUtil.addHexPrefix(strippedSignature.substr(0, 64)),
            s: ethUtil.addHexPrefix(strippedSignature.substr(64, 64)),
            v: parseInt(ethUtil.addHexPrefix(strippedSignature.substr(128, 2))) + 27
          }
          resolve(signature)
        })
    }
  })
}

module.exports.initialize = async (ownerAddress, raindropUsers) => {
  var instances = {}

  instances.token = await HydroToken.new({ from: ownerAddress })
  for (let i = 0; i < raindropUsers.length; i++) {
    await instances.token.transfer(raindropUsers[i].public, 1000 * 1e18, { from: ownerAddress })
  }

  instances.raindrop = await ClientRaindrop.new({ from: ownerAddress })
  await instances.raindrop.setHydroTokenAddress(instances.token.address, { from: ownerAddress })
  for (let i = 0; i < raindropUsers.length; i++) {
    await instances.raindrop.signUpUser(raindropUsers[i].hydroID, { from: raindropUsers[i].public })
  }

  instances.snowflake = await Snowflake.new({ from: ownerAddress })
  let receipt = await web3.eth.getTransactionReceipt(instances.snowflake.transactionHash)
  assert.isAtMost(receipt.cumulativeGasUsed, 6500000)

  await instances.snowflake.setAddresses(instances.raindrop.address, instances.token.address)

  return instances
}

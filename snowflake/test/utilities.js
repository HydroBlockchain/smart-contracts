const Web3 = require('web3')
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')
const ethUtil = require('ethereumjs-util')

function sign (messageHash, address, privateKey, method) {
  return new Promise(resolve => {
    if (method === 'unprefixed') {
      let signature = ethUtil.ecsign(
        Buffer.from(ethUtil.stripHexPrefix(messageHash), 'hex'),
        Buffer.from(ethUtil.stripHexPrefix(privateKey), 'hex')
      )
      signature.r = ethUtil.bufferToHex(signature.r)
      signature.s = ethUtil.bufferToHex(signature.s)
      signature.v = parseInt(ethUtil.bufferToHex(signature.v))
      resolve(signature)
    } else {
      web3.eth.sign(messageHash, address)
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

function timeTravel (seconds) {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [seconds],
      id: new Date().getTime()
    }, (err, result) => {
      if (err) return reject(err)
      return resolve(result)
    })
  })
}

async function verifyIdentity (identity, IdentityRegistry, expectedDetails) {
  const identityExists = await IdentityRegistry.identityExists(identity)
  assert.isTrue(identityExists, "identity unexpectedly does/doesn't exist.")

  for (const address of expectedDetails.associatedAddresses) {
    const hasIdentity = await IdentityRegistry.hasIdentity(address)
    assert.isTrue(hasIdentity, "address unexpectedly does/doesn't have an identity.")

    const onChainIdentity = await IdentityRegistry.getEIN(address)
    assert.isTrue(onChainIdentity.eq(identity), 'on chain identity was set incorrectly.')

    const isAddressFor = await IdentityRegistry.isAddressFor(identity, address)
    assert.isTrue(isAddressFor, 'associated address was set incorrectly.')
  }

  for (const provider of expectedDetails.providers) {
    const isProviderFor = await IdentityRegistry.isProviderFor(identity, provider)
    assert.isTrue(isProviderFor, 'provider was set incorrectly.')
  }

  for (const resolver of expectedDetails.resolvers) {
    const isResolverFor = await IdentityRegistry.isResolverFor(identity, resolver)
    assert.isTrue(isResolverFor, 'associated resolver was set incorrectly.')
  }

  const details = await IdentityRegistry.getDetails(identity)
  assert.equal(details.recoveryAddress, expectedDetails.recoveryAddress, 'unexpected recovery address.')
  assert.deepEqual(details.associatedAddresses, expectedDetails.associatedAddresses, 'unexpected associated addresses.')
  assert.deepEqual(details.providers, expectedDetails.providers, 'unexpected providers.')
  assert.deepEqual(details.resolvers, expectedDetails.resolvers, 'unexpected resolvers.')
}

module.exports = {
  sign: sign,
  timeTravel: timeTravel,
  verifyIdentity: verifyIdentity
}

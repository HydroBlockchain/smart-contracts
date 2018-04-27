const fs = require('fs')
const Web3 = require('web3') // 1.0.0-beta.34
const openpgp = require('openpgp')
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

const SnowflakeRegistry = artifacts.require('./SnowflakeRegistry.sol')

async function getKeyData () {
  const rawPGPKey = fs.readFileSync('./ProjectHydroPGPTestingKey.asc', {encoding: 'utf8'})
  var keyData = {
    publicKey: rawPGPKey.substr(0, 3179),
    secretKey: rawPGPKey.substr(3179),
    passphrase: 'projecthydro'
  }
  var secretKeyObject = openpgp.key.readArmored(keyData.secretKey).keys[0]
  await secretKeyObject.decrypt(keyData.passphrase)
  keyData.secretKeyObject = secretKeyObject
  return keyData
}

function encrypt (publicKey, plaintextData) {
  let options = {
    data: plaintextData,
    publicKeys: openpgp.key.readArmored(publicKey).keys
  }

  return new Promise(resolve => {
    openpgp.encrypt(options).then(ciphertext => {
      resolve(ciphertext.data)
    })
  })
}

function decrypt (secretKeyObject, ciphertextData) {
  let options = {
    message: openpgp.message.readArmored(ciphertextData),
    privateKeys: [keyData.secretKeyObject]
  }

  return new Promise(resolve => {
    openpgp.decrypt(options).then(plaintext => {
      resolve(plaintext.data)
    })
  })
}

contract('RaindropClient', function (accounts) {
  const owner = {
    public: accounts[0]
  }
  const application = {
    name: 'testApp',
    public: accounts[1]
  }

  var keyData
  var snowflakeInstance

  it('snowflake deployed', async function () {
    snowflakeInstance = await SnowflakeRegistry.new({from: owner.public})
  })

  it('key data loaded', async function () {
    let result = await getKeyData()
    keyData = result
  })

  it('add application', async function () {
    await snowflakeInstance.signUpApplication(
      application.name,
      application.public,
      false,
      keyData.publicKey,
      'RSA-4096'
    )
  })

  it('return bytes', async function () {
    let entry = await snowflakeInstance.getApplication.call(application.name)
    console.log(keyData.publicKey)
    console.log(entry)
  })

  it('signature stuff', async function () {
    var data = 'Hello World!'
    var encryptedData
    // encrypt(keyData, data).then(result => { encryptedData = result })
    // var decryptedData
    // decrypt(keyData, encryptedData).then(result => { decryptedData = result })
  })
})

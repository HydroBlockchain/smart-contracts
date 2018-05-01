const fs = require('fs')
const openpgp = require('openpgp')

async function getKeyData () {
  const rawPGPKey = fs.readFileSync('./test/ProjectHydroPGPTestingKey.asc', {encoding: 'utf8'})
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
    privateKeys: [secretKeyObject]
  }

  return new Promise(resolve => {
    openpgp.decrypt(options).then(plaintext => {
      resolve(plaintext.data)
    })
  })
}

module.exports = {
  getKeyData: getKeyData,
  encrypt: encrypt,
  decrypt: decrypt
}

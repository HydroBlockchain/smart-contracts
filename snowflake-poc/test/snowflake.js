const Web3 = require('web3') // 1.0.0-beta.34
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

const HydroToken = artifacts.require('./_testing/HydroToken.sol')
const ClientRaindrop = artifacts.require('./_testing/ClientRaindrop.sol')
const Snowflake = artifacts.require('./Snowflake.sol')

contract('Clean Room', function (accounts) {
  const owner = {
    public: accounts[0]
  }
  const user = {
    hydroID: 'p4hwf8t',
    public: accounts[1],
    private: '6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff',
    salt: web3.utils.keccak256('6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'),
    names: ['First', 'Middle', 'Last', 'Preferred'],
    dateOfBirth: ['30', '7', '2015'],
    emails: { 'Main Email': 'test@test.test' },
    phoneNumbers: { 'Mobile': '1234567890' },
    physicalAddresses: { 'Home': 'P. Sherman, 42 Wallaby Way, Sydney' }
  }

  var hydroInstance
  var raindropInstance
  var snowflakeInstance

  describe('Deploy and prepare testing-only contracts', async function () {
    it('hydro token deployed', async function () {
      hydroInstance = await HydroToken.new({from: owner.public})
    })

    it('Client Raindrop deployed', async function () {
      raindropInstance = await ClientRaindrop.new({ from: owner.public })
    })

    it('raindrop linked to token', async function () {
      await raindropInstance.setHydroTokenAddress(hydroInstance.address, {from: owner.public})
      let contractHydroTokenAddress = await raindropInstance.hydroTokenAddress()
      assert.equal(contractHydroTokenAddress, hydroInstance.address, 'address set incorrectly')
    })

    it('Client Raindrop user signed up', async function () {
      await raindropInstance.signUpUser(user.hydroID, {from: user.public})
    })
  })

  describe('Deploy and prepare snowflake', async function () {
    it('snowflake deployed', async function () {
      snowflakeInstance = await Snowflake.new({from: owner.public})
    })

    it('snowflake linked', async function () {
      await snowflakeInstance.setClientRaindropAddress(
        raindropInstance.address
      )
    })
  })

  describe('Test snowflake functionality', function () {
    it('mint identity token', async function () {
      let hashedNames = user.names.map(x => {
        web3.utils.soliditySha3({t: 'string', v: x}, {t: 'bytes32', v: user.salt})
      })
      let hashedDateOfBirth = user.dateOfBirth.map(x => {
        web3.utils.soliditySha3({t: 'string', v: x}, {t: 'bytes32', v: user.salt})
      })
      let tokenId = await snowflakeInstance.mintIdentityToken.call(
        hashedNames, hashedDateOfBirth, { from: user.public }
      )
      assert.equal(tokenId, '1')
      await snowflakeInstance.mintIdentityToken(hashedNames, hashedDateOfBirth, { from: user.public })
    })

    it('verify token ownership', async function () {
      let ownerOf = await snowflakeInstance.ownerOf.call(1)
      assert.equal(ownerOf, user.public)
      let tokenofAddress = await snowflakeInstance.tokenOfAddress.call(user.public)
      assert.equal(tokenofAddress, '1')
      let tokenofHydroID = await snowflakeInstance.tokenOfHydroID.call(user.hydroID)
      assert.equal(tokenofHydroID, '1')
    })
  //
  //   it('key stored correctly', async function () {
  //     let entry = await snowflakeInstance.getApplication.call(application.name)
  //     assert.equal(keyData.publicKey, entry[3])
  //     assert.equal('RSA-4096', entry[4])
  //   })
  //
  //   it('add user data', async function () {
  //     await snowflakeInstance.addDataDelegated(
  //       raindropDelegatedUser.public,
  //       raindropDelegatedUser.name,
  //       [web3.utils.keccak256(dataField)],
  //       [web3.utils.keccak256(raindropDelegatedUser[dataField], raindropDelegatedUser.salt)],
  //       { from: owner.public }
  //     )
  //   })
  //
  //   it('verify user data', async function () {
  //     let saltedHashes = await snowflakeInstance.getSaltedHashes.call(raindropDelegatedUser.name, dataField)
  //     assert.deepEqual(
  //       saltedHashes,
  //       [web3.utils.keccak256(raindropDelegatedUser[dataField], raindropDelegatedUser.salt)],
  //       'data stored incorrectly'
  //     )
  //   })
  //
  //   it('passed data can be decrypted with on-chain public key', async function () {
  //     let applicationData = await snowflakeInstance.getApplication.call(application.name)
  //     let publicKey = applicationData[3]
  //     let encryptedField = await keyUtils.encrypt(
  //       publicKey,
  //       JSON.stringify({
  //         [dataField]: raindropDelegatedUser[dataField],
  //         salt: raindropDelegatedUser.salt
  //       })
  //     )
  //     let decryptedData = JSON.parse(await keyUtils.decrypt(keyData.secretKeyObject, encryptedField))
  //     let receivedSaltedHash = web3.utils.keccak256(decryptedData[dataField], decryptedData.salt)
  //     let onChainSaltedHashes = await snowflakeInstance.getSaltedHashes.call(raindropDelegatedUser.name, dataField)
  //     assert.include(onChainSaltedHashes, receivedSaltedHash, 'received data did not match on-chain data')
  //   })
  //
  //   it('delete user data', async function () {
  //     await snowflakeInstance.removeDataDelegated(
  //       raindropDelegatedUser.public,
  //       raindropDelegatedUser.name,
  //       [web3.utils.keccak256(dataField)],
  //       [web3.utils.keccak256(raindropDelegatedUser[dataField], raindropDelegatedUser.salt)]
  //     )
  //   })
  //
  //   it('delete application', async function () {
  //     await snowflakeInstance.deleteApplication(web3.utils.keccak256(application.name))
  //   })
  })
})

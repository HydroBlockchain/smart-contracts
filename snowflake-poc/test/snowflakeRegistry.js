const keyUtils = require('./keyUtils')
const Web3 = require('web3') // 1.0.0-beta.34
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

const SnowflakeRegistry = artifacts.require('./SnowflakeRegistry.sol')
const HydroToken = artifacts.require('./_testing/HydroToken.sol')
const RaindropClient = artifacts.require('./_testing/RaindropClient.sol')

contract('RaindropClient', function (accounts) {
  const owner = {
    public: accounts[0]
  }
  const hydro = {
    public: accounts[1]
  }
  const application = {
    name: 'testApp',
    public: accounts[2]
  }
  const raindropDelegatedUser = {
    name: 'delegatedUser',
    Email: 'test@test.test',
    salt: 52304582093458,
    public: '0xcd01cd6b160d2bcbee75b59c393d0017e6bbf427',
    r: '0x6c295a85cad022650e5e4c7dc122ad3d712dace1fa873b35baed8fb8506ea9a6',
    s: '0x284f1b9c7a1ff438388fa5942af08fefd6cb0e170d88f4838b667b5b930e335d',
    v: 28
  }
  const raindropUser = {
    name: 'test',
    public: accounts[4],
    Email: 'test@test.test',
    salt: '1782035713204973210947' // a random # between 0 and 2**256 - 1 inclusive
  }

  const dataField = 'Email'

  var keyData

  var hydroInstance
  var raindropInstance
  var snowflakeInstance

  describe('Deployment and Linking', async function () {
    it('hydro token deployed', async function () {
      hydroInstance = await HydroToken.new({from: owner.public})
    })

    it('raindropInstance deployed', async function () {
      raindropInstance = await RaindropClient.new({ from: owner.public })
    })

    it('raindrop linked to token', async function () {
      await raindropInstance.setHydroTokenAddress(hydroInstance.address, {from: owner.public})
      let contractHydroTokenAddress = await raindropInstance.hydroTokenAddress()
      assert.equal(contractHydroTokenAddress, hydroInstance.address, 'address set incorrectly')
    })

    it('raindropClient user signed up', async function () {
      await raindropInstance.signUpUser(raindropUser.name, {from: raindropUser.public})
    })

    it('raindropClient delegated user signed up', async function () {
      await raindropInstance.signUpDelegatedUser(
        raindropDelegatedUser.name,
        raindropDelegatedUser.public,
        raindropDelegatedUser.v,
        raindropDelegatedUser.r,
        raindropDelegatedUser.s,
        {from: owner.public}
      )
    })

    it('snowflake deployed', async function () {
      snowflakeInstance = await SnowflakeRegistry.new({from: owner.public})
    })

    it('snowflake addresses set', async function () {
      await snowflakeInstance.modifyContractAddresses(
        0x0, // add the escrow address once migration stops throwing errors
        hydroInstance.address,
        raindropInstance.address
      )
    })

    it('key data loaded', async function () {
      keyData = await keyUtils.getKeyData()
    })

    it('key type added', async function () {
      await snowflakeInstance.addKeyType('RSA-4096')
    })

    it('data field added', async function () {
      await snowflakeInstance.addDataField(dataField)
    })
  })

  describe('Functionality', async function () {
    it('add application', async function () {
      await snowflakeInstance.signUpApplication(
        application.name,
        application.public,
        hydro.public,
        hydro.public,
        keyData.publicKey,
        'RSA-4096',
        { from: owner.public }
      )
    })

    it('key stored correctly', async function () {
      let entry = await snowflakeInstance.getApplication.call(application.name)
      assert.equal(keyData.publicKey, entry[3])
      assert.equal('RSA-4096', entry[4])
    })

    it('add user data', async function () {
      await snowflakeInstance.addDataDelegated(
        raindropDelegatedUser.public,
        raindropDelegatedUser.name,
        [web3.utils.keccak256(dataField)],
        [web3.utils.keccak256(raindropDelegatedUser[dataField], raindropDelegatedUser.salt)],
        { from: owner.public }
      )
    })

    it('verify user data', async function () {
      let saltedHashes = await snowflakeInstance.getSaltedHashes.call(raindropDelegatedUser.name, dataField)
      assert.deepEqual(
        saltedHashes,
        [web3.utils.keccak256(raindropDelegatedUser[dataField], raindropDelegatedUser.salt)],
        'data stored incorrectly'
      )
    })

    it('passed data can be decrypted with on-chain public key', async function () {
      let applicationData = await snowflakeInstance.getApplication.call(application.name)
      let publicKey = applicationData[3]
      let encryptedField = await keyUtils.encrypt(
        publicKey,
        JSON.stringify({
          [dataField]: raindropDelegatedUser[dataField],
          salt: raindropDelegatedUser.salt
        })
      )
      let decryptedData = JSON.parse(await keyUtils.decrypt(keyData.secretKeyObject, encryptedField))
      let receivedSaltedHash = web3.utils.keccak256(decryptedData[dataField], decryptedData.salt)
      let onChainSaltedHashes = await snowflakeInstance.getSaltedHashes.call(raindropDelegatedUser.name, dataField)
      assert.include(onChainSaltedHashes, receivedSaltedHash, 'received data did not match on-chain data')
    })

    it('delete user data', async function () {
      await snowflakeInstance.removeDataDelegated(
        raindropDelegatedUser.public,
        raindropDelegatedUser.name,
        [web3.utils.keccak256(dataField)],
        [web3.utils.keccak256(raindropDelegatedUser[dataField], raindropDelegatedUser.salt)]
      )
    })

    it('delete application', async function () {
      await snowflakeInstance.deleteApplication(web3.utils.keccak256(application.name))
    })
  })
})

const Web3 = require('web3') // 1.0.0-beta.34
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

const HydroToken = artifacts.require('./_testing/HydroToken.sol')
const ClientRaindrop = artifacts.require('./_testing/ClientRaindrop.sol')
const Snowflake = artifacts.require('./Snowflake.sol')

contract('Clean Room', function (accounts) {
  const owner = {
    public: accounts[0]
  }
  var user = {
    hydroID: 'p4hwf8t',
    public: accounts[1],
    private: '6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff',
    names: ['Prefix', 'First', 'Middle', 'Last', 'Suffix', 'Preferred'],
    dateOfBirth: ['30', '7', '2015'],
    emails: { 'Main Email': 'test@test.test' },
    phoneNumbers: { 'Mobile': '1234567890' },
    physicalAddresses: { 'Home': 'P. Sherman, 42 Wallaby Way, Sydney' }
  }
  user.salt = web3.utils.soliditySha3({t: 'bytes32', v: `0x${user.private}`}, {t: 'address', v: user.public})
  const hashedNames = user.names.map(x => {
    return web3.utils.soliditySha3({t: 'string', v: x}, {t: 'bytes32', v: user.salt})
  })
  const hashedDateOfBirth = user.dateOfBirth.map(x => {
    return web3.utils.soliditySha3({t: 'string', v: x}, {t: 'bytes32', v: user.salt})
  })

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
      await snowflakeInstance.setHydroTokenAddress(
        hydroInstance.address
      )
    })
  })

  describe('Test snowflake functionality', function () {
    it('mint identity token', async function () {
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

    it('verify token details', async function () {
      let tokenDetails = await snowflakeInstance.tokenDetails.call(1)
      assert.equal(tokenDetails[0], user.public)
      assert.equal(tokenDetails[1], user.hydroID)
      assert.deepEqual(tokenDetails[2].map(x => { return x.toNumber() }), [0, 1])
      assert.deepEqual(tokenDetails[3], [])
    })

    it('verify field details', async function () {
      let nameDetails = await snowflakeInstance.fieldDetails.call(1, 0)
      console.log(nameDetails)
      // assert.deepEqual(nameDetails[0], ['prefix', 'givenName', 'middleName', 'surname', 'suffix', 'preferredName'])
      // assert.deepEqual(nameDetails[1], [])
    })

    it('verify entry details', async function () {
      let givenNameEntryDetails = await snowflakeInstance.entryDetails.call(1, 0, 'prefix')
      console.log(givenNameEntryDetails)
      // assert.deepEqual(nameDetails[0], ['prefix', 'givenName', 'middleName', 'surname', 'suffix', 'preferredName'])
      // assert.deepEqual(nameDetails[1], [])
    })
  })
})

const common = require('./common.js')
const Web3 = require('web3') // 1.0.0-beta.34
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

const AddressOwnership = artifacts.require('./resolvers/AddressOwnership.sol')
const HydroReputation = artifacts.require('./resolvers/HydroReputation.sol')
const HydroKYC = artifacts.require('./resolvers/HydroKYC.sol')

contract('Clean Room', function (accounts) {
  const owner = {
    public: accounts[0]
  }
  var user1 = {
    hydroID: 'p4hwf8t',
    public: accounts[1],
    private: '6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff',
    names: ['Prefix', 'First', 'Middle', 'Last', 'Suffix', 'Preferred'],
    dateOfBirth: ['30', '7', '2015'],
    emails: { 'Main Email': 'test@test.test' },
    phoneNumbers: { 'Mobile': '1234567890' },
    physicalAddresses: { 'Home': 'P. Sherman, 42 Wallaby Way, Sydney' }
  }
  var user2 = {
    hydroID: 'p4hwf8l',
    public: accounts[2],
    private: '6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff',
    names: ['Prefix', 'First', 'Middle', 'Last', 'Suffix', 'Preferred'],
    dateOfBirth: ['30', '7', '2015'],
    emails: { 'Main Email': 'test@test.test' },
    phoneNumbers: { 'Mobile': '1234567890' },
    physicalAddresses: { 'Home': 'P. Sherman, 42 Wallaby Way, Sydney' }
  }
  user1.salt = web3.utils.soliditySha3({t: 'bytes32', v: `0x${user1.private}`}, {t: 'address', v: user1.public})
  const encrypt = (strings, salt) => {
    return strings.map(x => { return web3.utils.soliditySha3({ t: 'string', v: x }, { t: 'bytes32', v: salt }) })
  }
  const hashedNames = encrypt(user1.names, user1.salt)
  const hashedDateOfBirth = encrypt(user1.dateOfBirth, user1.salt)
  const hashedEmails = encrypt(Object.values(user1.emails), user1.salt)
  const hashedPhone = encrypt(Object.values(user1.phoneNumbers), user1.salt)
  const hashedAddresses = encrypt(Object.values(user1.physicalAddresses), user1.salt)

  const nameOrder = ['prefix', 'givenName', 'middleName', 'surname', 'suffix', 'preferredName']
  const dateOrder = ['day', 'month', 'year']

  const fields = {
    Name: 0,
    DateOfBirth: 1,
    Emails: 2,
    PhoneNumbers: 3,
    PhysicalAddresses: 4
  }

  var instances

  it('common contracts deployed', async function () {
    instances = await common.initialize(owner.public, [user1, user2])
  })

  describe('Test snowflake functionality', function () {
    it('mint identity token', async function () {
      let tokenId = await instances.snowflake.mintIdentityToken.call(
        hashedNames, hashedDateOfBirth, { from: user1.public }
      )
      assert.equal(tokenId, '1')
      await instances.snowflake.mintIdentityToken(hashedNames, hashedDateOfBirth, { from: user1.public })
    })

    it('verify token details', async function () {
      let tokenDetails = await instances.snowflake.getDetails.call(1)
      assert.equal(tokenDetails[0], user1.public)
      assert.equal(tokenDetails[1], user1.hydroID)
      assert.deepEqual(tokenDetails[2], ['0', '1'])
      assert.deepEqual(tokenDetails[3], [])

      let tokenofAddress = await instances.snowflake.getTokenId.call(user1.public)
      assert.equal(tokenofAddress, '1')
    })

    it('verify field details', async function () {
      // let nameDetails = await instances.snowflake.methods['getDetails(uint256,uint8)'].call(1, fields.Name)
      // assert.deepEqual(nameDetails[0], nameOrder)

      // let dateDetails = await instances.snowflake.methods['getDetails(uint256,uint8)'].call(1, fields.DateOfBirth)
      // assert.deepEqual(dateDetails[0], dateOrder)
    })

    it('verify entry details', async function () {
      var nameEntryDetails
      for (let i = 0; i < user1.names.length; i++) {
        nameEntryDetails = await instances.snowflake.methods['getDetails(uint256,uint8,string)']
          .call(1, fields.Name, nameOrder[i])
        assert.equal(nameEntryDetails[0], hashedNames[i])
        assert.equal(nameEntryDetails[1], await web3.eth.getBlockNumber())
      }
      var birthEntryDetails
      for (let i = 0; i < user1.dateOfBirth.length; i++) {
        birthEntryDetails = await instances.snowflake.methods['getDetails(uint256,uint8,string)']
          .call(1, fields.DateOfBirth, dateOrder[i])
        assert.equal(birthEntryDetails[0], hashedDateOfBirth[i])
        assert.equal(birthEntryDetails[1], await web3.eth.getBlockNumber())
      }
    })

    it('add new fields', async function () {
      await instances.snowflake.addFieldEntry(
        fields.Emails, Object.keys(user1.emails)[0], hashedEmails[0], { from: user1.public }
      )
      await instances.snowflake.addFieldEntry(
        fields.PhoneNumbers, Object.keys(user1.phoneNumbers)[0], hashedPhone[0], { from: user1.public }
      )
      await instances.snowflake.addFieldEntry(
        fields.PhysicalAddresses, Object.keys(user1.physicalAddresses)[0], hashedAddresses[0], { from: user1.public }
      )
    })

    it('verify updated token details', async function () {
      let tokenDetails = await instances.snowflake.getDetails.call(1)
      assert.deepEqual(tokenDetails[2], ['0', '1', '2', '3', '4'])
    })

    it('verify new field details', async function () {
      // let emailDetails = await instances.snowflake.methods['getDetails(uint256,uint8)'].call(1, fields.Emails)
      // assert.deepEqual(emailDetails, Object.keys(user1.emails))

      // let phoneDetails = await instances.snowflake.methods['getDetails(uint256,uint8)'].call(1, fields.PhoneNumbers)
      // assert.deepEqual(phoneDetails, Object.keys(user1.phoneNumbers))

      // let addressDetails = await instances.snowflake.methods['getDetails(uint256,uint8)']
      //   .call(1, fields.PhysicalAddresses)
      // assert.deepEqual(addressDetails, Object.keys(user1.physicalAddresses))
    })

    it('verify new entry details', async function () {
      var emailEntryDetails = await instances.snowflake.methods['getDetails(uint256,uint8,string)']
        .call(1, fields.Emails, Object.keys(user1.emails)[0])
      assert.equal(emailEntryDetails.saltedHash, hashedEmails)

      var phoneEntryDetails = await instances.snowflake.methods['getDetails(uint256,uint8,string)']
        .call(1, fields.PhoneNumbers, Object.keys(user1.phoneNumbers)[0])
      assert.equal(phoneEntryDetails.saltedHash, hashedPhone)

      var addressEntryDetails = await instances.snowflake.methods['getDetails(uint256,uint8,string)']
        .call(1, fields.PhysicalAddresses, Object.keys(user1.physicalAddresses)[0])
      assert.equal(addressEntryDetails.saltedHash, hashedAddresses)
    })
  })

  describe('Hydro Reputation', function () {
    it('hydro reputation deployed', async function () {
      instances.reputation = await HydroReputation.new({ from: owner.public })
      await instances.reputation.setSnowflakeAddress(instances.snowflake.address)
    })

    it('join hydro reputation', async function () {
      await instances.reputation.joinHydroReputation({from: user1.public})
      await instances.snowflake.mintIdentityToken(hashedNames, hashedDateOfBirth, { from: user2.public })
      await instances.reputation.joinHydroReputation({from: user2.public})
    })

    it('add field and attest to field', async function () {
      await instances.reputation.addReputationField('Hydro Is Awesome!!', {from: user1.public})
      await instances.reputation.attestToReputation(user1.public, 'Hydro Is Awesome!!', { from: user2.public })
    })

    it('add duplicate field fail', async function () {
      instances.reputation.addReputationField.call('Hydro Is Awesome!!', {from: user1.public})
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })

    it('attest duplicate field fail', async function () {
      instances.reputation.attestToReputation.call(user1.public, 'Hydro Is Awesome!!', {from: user2.public})
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })

    it('get reputation for added field', async function () {
      let repCount = await instances.reputation.getReputation.call(user1.public, 'Hydro Is Awesome!!', {from: user2.public})
      assert.equal(repCount, 1)
    })

    it('get reputation list for added field', async function () {
      let repList = await instances.reputation.getReputationList.call(user1.public, 'Hydro Is Awesome!!', {from: user2.public})
      assert.equal(repList[0], user2.public)
    })

    it('get single reputation for added field', async function () {
      let rep = await instances.reputation.getReputationIndividual.call(user1.public, 'Hydro Is Awesome!!', 0, {from: user2.public})
      assert.equal(rep, user2.public)
    })

    it('get nonexistant rep fail', async function () {
      instances.reputation.getReputationIndividual.call(user1.public, 'Hydro Is Awesome!!', 45, {from: user2.public})
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })
  })

  describe('Address Ownership', function () {
    it('address ownership deployed', async function () {
      instances.addresses = await AddressOwnership.new({ from: owner.public })
      await instances.addresses.setSnowflakeAddress(instances.snowflake.address)
    })

    user2.addressSecret = web3.utils.soliditySha3('shhhh')
    it('happy path tests', async function () {
      // user2 claiming user1
      var claim = await web3.utils.soliditySha3('Link Address to Snowflake', user1.public, user2.addressSecret)
      await instances.addresses.initiateClaim(claim, {from: user2.public})

      var signedMessage = await common.sign(claim, user1, 'unprefixed')
      await instances.addresses.finalizeClaim(
        user1.public, signedMessage.v, signedMessage.r, signedMessage.s, user2.addressSecret, { from: user2.public }
      )

      var tokenId = await instances.snowflake.getTokenId.call(user2.public)
      var ownedAddresses = await instances.addresses.ownedAddresses.call(parseInt(tokenId))
      assert.deepEqual(ownedAddresses, [user1.public])

      var ownsAddress = await instances.addresses.ownsAddress.call(parseInt(tokenId), user1.public)
      assert.equal(ownsAddress, true)

      await instances.addresses.unclaimAddress(user1.public, {from: user2.public})
    })

    it('own no addresses', async function () {
      var tokenId = await instances.snowflake.getTokenId.call(user1.public)
      let addresses = await instances.addresses.ownedAddresses.call(parseInt(tokenId))
      assert.deepEqual(addresses, [])

      var ownedAddress = await instances.addresses.ownsAddress.call(parseInt(tokenId), user2.public)
      assert.equal(ownedAddress, false)
    })

    var incorrectSecret = web3.utils.soliditySha3('random stuff')
    it('fail to sign', async function () {
      var claim = await web3.utils.soliditySha3('Link Address to Snowflake', user1.public, incorrectSecret)

      await instances.addresses.initiateClaim(claim, {from: user2.public})

      var signedMessage = await common.sign(claim, user2, 'unprefixed')
      await instances.addresses.finalizeClaim.call(
        user1.public, signedMessage.v, signedMessage.r, signedMessage.s, user2.addressSecret, {from: user2.public}
      )
        .then(() => { assert.fail('', '', 'call should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })

    it('submit an already submitted hash', async function () {
      var claim = await web3.utils.soliditySha3('Link Address to Snowflake', user1.public, user2.addressSecret)

      await instances.addresses.initiateClaim.call(claim, {from: user2.public})
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })
  })

  describe('KYC Tests', function () {
    it('hydro kyc deployed', async function () {
      instances.KYC = await HydroKYC.new({ from: owner.public })
      await instances.KYC.setSnowflakeAddress(instances.snowflake.address)
    })

    var standard = web3.utils.keccak256('standard')
    it('happy path tests', async function () {
      await instances.KYC.addKYCStandard(standard, {from: user1.public})
      await instances.KYC.attestToUsersKYC(standard, 1, {from: user2.public})

      var count = await instances.KYC.getAttestationCountToUser(standard, 1, {from: user2.public})
      assert.equal(count, 1)

      var addresses = await instances.KYC.getAttestationsToUser(standard, 1, {from: user2.public})
      assert.equal(addresses.length, 1)
      assert.equal(addresses[0], user2.public)

      var blockNumber = await instances.KYC.getTimeOfAttestation(standard, 1, user2.public, {from: user2.public})
      assert.equal(blockNumber, await web3.eth.getBlockNumber())
    })

    it('standard already added', async function () {
      await instances.KYC.addKYCStandard.call(standard, {from: user1.public})
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })

    it('snowflake doesnt exist', async function () {
      await instances.KYC.attestToUsersKYC.call(standard, 100, {from: user2.public})
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })

    it('standard doesnt exist', async function () {
      await instances.KYC.attestToUsersKYC.call(standard, 1, {from: user2.public})
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })
  })
})

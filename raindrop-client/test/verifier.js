// start ganache with: ganache-cli --seed hydro
// run tests with: truffle test --network ganache
const Web3 = require('web3') // 1.0.0-beta.33
const web3 = new Web3(Web3.givenProvider)
var util = require('ethereumjs-util')

var Verifier = artifacts.require('./Verifier.sol')

contract('Verifier', function (accounts) {
  const owner = {
    public: accounts[0],
    private: '2665671af93f210ddb5d5ffa16c77fcf961d52796f2b2d7afd32cc5d886350a8'
  }
  const officialUser = {
    name: 'AppUser',
    public: accounts[1],
    private: '6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
  }
  const unofficialUser = {
    name: 'h4ck3r',
    public: accounts[2],
    private: 'ccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
  }
  const officialApplications = [
    'Totally Trustworthy Tech Titan',
    'totally trustworthy tech titan',
    'Not Stealing Your Data™',
    '阿里巴巴集团控股有限公司',
    '⭐⭐⭐⭐⭐'
  ]
  const unofficialApplications = [
    'totally trustworthy tech titan',
    'fakebook'
  ]

  var instance

  var userFee
  var applicationFee

  it('verifier deployed', async function () {
    instance = await Verifier.new({from: owner.public})
  })

  it('sign up fees are settable', async function () {
    userFee = 10 ** 18 / 10 // .1 ether in wei
    applicationFee = 10 ** 18 // 1 ether in wei
    await instance.setUnofficialUserSignUpFee(userFee, {from: owner.public})
    await instance.setUnofficialApplicationSignUpFee(applicationFee, {from: owner.public})
    let contractUserFee = await instance.unofficialUserSignUpFee()
    let contractApplicationFee = await instance.unofficialApplicationSignUpFee()
    assert.equal(contractUserFee, userFee, 'user fee incorrectly updated')
    assert.equal(contractApplicationFee, applicationFee, 'application fee incorrectly updated')
  })

  it('official applications signed up', async function () {
    for (let i = 0; i < officialApplications.length; i++) {
      await instance.officialApplicationSignUp(officialApplications[i], {from: owner.public})
      let officialApplicationExists = await instance.applicationNameTaken(officialApplications[i], true)
      assert.isTrue(officialApplicationExists, 'application signed up incorrectly')
    }
  })

  it('insufficiently funded unofficial application requests rejected', function () {
    return instance.unofficialApplicationSignUp.call(unofficialApplications[0])
      .then(() => { assert.fail('', '', 'application should have been rejected') })
      .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
  })

  it('funded but malformed unofficial application requests rejected', function () {
    let badNames = ['a'.repeat(100), 'ABC']
    for (let i = 0; i < badNames.length; i++) {
      instance.unofficialApplicationSignUp.call(badNames[i], {value: applicationFee})
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    }
  })

  it('unofficial application requests accepted', async function () {
    for (let i = 0; i < unofficialApplications.length; i++) {
      await instance.unofficialApplicationSignUp(unofficialApplications[i], {value: applicationFee})
      let unofficialApplicationExists = await instance.applicationNameTaken(unofficialApplications[i], false)
      assert.isTrue(unofficialApplicationExists, 'application signed up incorrectly')
    }
  })

  it('first official user signed up', async function () {
    await instance.officialUserSignUp(officialUser.name, officialUser.public, {from: owner.public})
    let officialUserExists = await instance.userNameTaken(officialUser.name)
    assert.isTrue(officialUserExists, 'user signed up incorrectly')
    let userDetails = await instance.getUserByName(officialUser.name)
    assert.equal(userDetails[0], officialUser.public, 'user address stored incorrectly')
    assert.equal(userDetails[1], true, 'user offical status stored incorrectly')
  })

  it('insufficiently funded unofficial user requests rejected', async function () {
    await instance.unofficialUserSignUp.call(unofficialUser.name, {from: unofficialUser.public})
      .then(() => { assert.fail('', '', 'user should have been rejected') })
      .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
  })

  it('funded but malformed unofficial user requests rejected', async function () {
    let badUserName = 'A'.repeat(100)
    await instance.unofficialUserSignUp.call(badUserName, {from: unofficialUser.public, value: userFee})
      .then(() => { assert.fail('', '', 'user should have been rejected') })
      .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
  })

  it('first unofficial user signed up', async function () {
    await instance.unofficialUserSignUp(unofficialUser.name, {from: unofficialUser.public, value: userFee})
    let unofficialUserExists = await instance.userNameTaken(unofficialUser.name)
    assert.isTrue(unofficialUserExists, 'user signed up incorrectly')
    let userDetails = await instance.getUserByName(unofficialUser.name)
    assert.equal(userDetails[0], unofficialUser.public, 'user address stored incorrectly')
    assert.equal(userDetails[1], false, 'user offical status stored incorrectly')
  })

  it('all added applications and user names should be locked', function () {
    let officialUserPromises = [
      instance.officialUserSignUp.call(officialUser.name, officialUser.public, {from: owner.public})
        .then(() => { assert.fail('', '', 'user should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    ]
    let unofficialUserPromises = [
      instance.unofficialUserSignUp.call(unofficialUser.name, {from: unofficialUser.public})
        .then(() => { assert.fail('', '', 'user should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    ]
    let officialApplicationPromises = officialApplications.map(function (x) {
      return instance.officialApplicationSignUp.call(x, {from: owner.public})
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })
    let unofficialApplicationPromises = unofficialApplications.map(function (x) {
      return instance.unofficialApplicationSignUp.call(x)
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    })
    return Promise.all(
      officialUserPromises + unofficialUserPromises + officialApplicationPromises + unofficialApplicationPromises
    )
  })

  it('should be able to recover signed messages', async function () {
    let challengeString = '123456'
    let challengeStringHash = util.addHexPrefix(util.sha3(challengeString).toString('hex'))
    let signature = util.ecsign(
      Buffer.from(util.stripHexPrefix(challengeStringHash), 'hex'), Buffer.from(officialUser.private, 'hex')
    )
    let v = signature.v
    let r = util.bufferToHex(signature.r)
    let s = util.bufferToHex(signature.s)
    let recoveredAddress = await instance.recoverAddress.call(challengeStringHash, v, r, s)
    assert.equal(recoveredAddress, officialUser.public, 'unexpected recovered address')
  })

  it('official user deleted', async function () {
    let deleteString = 'Delete'
    let deleteStringHash = util.addHexPrefix(util.sha3(deleteString).toString('hex'))
    let signature = util.ecsign(
      Buffer.from(util.stripHexPrefix(deleteStringHash), 'hex'), Buffer.from(officialUser.private, 'hex')
    )
    let v = signature.v
    let r = util.bufferToHex(signature.r)
    let s = util.bufferToHex(signature.s)
    await instance.deleteUserForUser(officialUser.name, v, r, s, {from: owner.public})
    let officialUserExists = await instance.userNameTaken(officialUser.name)
    assert.isFalse(officialUserExists, 'user deleted incorrectly')
  })

  it('unofficial user deleted', async function () {
    await instance.deleteUser(unofficialUser.name, {from: unofficialUser.public})
    let unofficialUserExists = await instance.userNameTaken(unofficialUser.name)
    assert.isFalse(unofficialUserExists, 'user deleted incorrectly')
  })

  it('should be able to withdraw ether', async function () {
    await instance.withdrawEther(owner.public, {from: owner.public})
    let contractBalance = await web3.eth.getBalance(instance.address)
    assert.equal(contractBalance, '0', 'contract funds not emptied')
  })
})

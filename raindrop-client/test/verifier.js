// start ganache with: ganache-cli --seed hydro --port 8555
// run tests with: truffle test --network ganache
const Web3 = require('web3') // 1.0.0-beta.34
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')
const util = require('ethereumjs-util')

var RaindropClient = artifacts.require('./RaindropClient.sol')
var HydroToken = artifacts.require('./_testing/HydroToken.sol')

contract('RaindropClient', function (accounts) {
  const owner = {
    public: accounts[0]
  }
  const hydroOwner = {
    public: accounts[1]
  }
  const user = {
    name: 'h4ck3R',
    public: accounts[2],
    private: 'ccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
  }
  const delegatedUser = {
    name: 'Noah',
    public: accounts[3],
    private: 'fdf12368f9e0735dc01da9db58b1387236120359024024a31e611e82c8853d7f'
  }
  const badUser = {
    name: 'A'.repeat(100),
    public: accounts[4]
  }
  const maliciousAdder = {
    public: accounts[5]
  }

  const minimumHydroStakeUser = 100
  const minimumHydroStakeDelegatedUser = 1000

  const signingMethods = ['unprefixed', 'prefixed']
  const permissionString = 'Create RaindropClient Hydro Account'

  var hydroInstance
  var raindropInstance

  function sign (message, user, method) {
    return new Promise((resolve, reject) => {
      let messageHash = web3.utils.keccak256(message)
      if (method === 'unprefixed') {
        let signature = util.ecsign(
          Buffer.from(util.stripHexPrefix(messageHash), 'hex'), Buffer.from(user.private, 'hex')
        )
        signature.r = util.bufferToHex(signature.r)
        signature.s = util.bufferToHex(signature.s)
        // console.log('Message:', message)
        // console.log('Address:', user.public)
        // console.log(signature)
        resolve(signature)
      } else {
        web3.eth.sign(messageHash, user.public)
          .then(concatenatedSignature => {
            let strippedSignature = util.stripHexPrefix(concatenatedSignature)
            let signature = {
              r: util.addHexPrefix(strippedSignature.substr(0, 64)),
              s: util.addHexPrefix(strippedSignature.substr(64, 64)),
              v: parseInt(util.addHexPrefix(strippedSignature.substr(128, 2))) + 27
            }
            resolve(signature)
          })
      }
    })
  }

  it('hydro token deployed', async function () {
    hydroInstance = await HydroToken.new({from: hydroOwner.public})
  })

  it('raindrop client deployed and linked to the Hydro token', async function () {
    raindropInstance = await RaindropClient.new({from: owner.public})
  })

  it('raindrop linked to token', async function () {
    await raindropInstance.setHydroTokenAddress(hydroInstance.address, {from: owner.public})
    let contractHydroTokenAddress = await raindropInstance.hydroTokenAddress()
    assert.equal(contractHydroTokenAddress, hydroInstance.address, 'address set incorrectly')
  })

  it('malformed user signups rejected', async function () {
    let signUpPromise = raindropInstance.signUpUser.call(badUser.name, {from: badUser.public})
      .then(() => { assert.fail('', '', 'user should have been rejected') })
      .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
    await signUpPromise
  })

  it('user signed up', async function () {
    await raindropInstance.signUpUser(user.name, {from: user.public})
  })

  it('user details are correct', async function () {
    let userNameTaken = await raindropInstance.userNameTaken(user.name)
    assert.isTrue(userNameTaken, 'user signed up incorrectly')
    let userDetailsByName = await raindropInstance.getUserByName(user.name)
    console.log(userDetailsByName)
    assert.equal(userDetailsByName[0], user.public, 'user address stored incorrectly')
    assert.equal(userDetailsByName[1], false, 'user delegated status stored incorrectly')
    let userDetailsByAddress = await raindropInstance.getUserByAddress(user.public)
    console.log(userDetailsByAddress)
    assert.equal(userDetailsByAddress[0], user.name, 'user name stored incorrectly')
    assert.equal(userDetailsByAddress[1], false, 'user delegated status stored incorrectly')
  })

  it('staking minimums are settable', async function () {
    await raindropInstance.setMinimumHydroStakes(
      minimumHydroStakeUser, minimumHydroStakeDelegatedUser, {from: owner.public}
    )
    let contractMinimumHydroStakeUser = await raindropInstance.minimumHydroStakeUser()
    let contractMinimumHydroStakeDelegatedUser = await raindropInstance.minimumHydroStakeDelegatedUser()
    assert.equal(contractMinimumHydroStakeUser.toNumber(), minimumHydroStakeUser, 'fee incorrectly updated')
    assert.equal(
      contractMinimumHydroStakeDelegatedUser.toNumber(), minimumHydroStakeDelegatedUser, 'fee incorrectly updated'
    )
  })

  it('insufficiently staked delegated user sign up rejected', async function () {
    let signUpPromises = signingMethods.map(method => {
      return sign(permissionString, delegatedUser, method)
        .then(signature => {
          raindropInstance.signUpDelegatedUser.call(
            delegatedUser.name, delegatedUser.public, signature.v, signature.r, signature.s, {from: owner.public}
          )
            .then(() => { assert.fail('', '', 'delegated user should not have been able to sign up') })
            .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
        })
        .catch(e => { assert.fail('', '', 'signature error') })
    })
    await Promise.all(signUpPromises)
  })

  it('transferred hydro tokens', async function () {
    await hydroInstance.transfer(user.public, minimumHydroStakeUser, {from: hydroOwner.public})
    await hydroInstance.transfer(owner.public, minimumHydroStakeDelegatedUser, {from: hydroOwner.public})
    await hydroInstance.transfer(maliciousAdder.public, minimumHydroStakeDelegatedUser, {from: hydroOwner.public})
    let userHydroBalance = await hydroInstance.balanceOf(user.public)
    let ownerHydroBalance = await hydroInstance.balanceOf(owner.public)
    let maliciousAdderHydroBalance = await hydroInstance.balanceOf(maliciousAdder.public)
    assert.equal(userHydroBalance.toNumber(), minimumHydroStakeUser, 'bad token transfer')
    assert.equal(ownerHydroBalance.toNumber(), minimumHydroStakeDelegatedUser, 'bad token transfer')
    assert.equal(maliciousAdderHydroBalance.toNumber(), minimumHydroStakeDelegatedUser, 'bad token transfer')
  })

  it('delegated user signed up', async function () {
    // make sure both types of permissions work
    let signUpPromises = signingMethods.map(method => {
      return sign(permissionString, delegatedUser, method)
        .then(signature => {
          raindropInstance.signUpDelegatedUser.call(
            delegatedUser.name, delegatedUser.public, signature.v, signature.r, signature.s, {from: owner.public}
          )
            .then(() => {})
            .catch(() => { assert.fail('', '', 'user should have been signed up') })
        })
        .catch(e => { assert.fail('', '', 'signature error') })
    })
    await Promise.all(signUpPromises)
    // arbitrarily submit the unprefixed permission
    let signature = await sign(permissionString, delegatedUser, 'prefixed')
    await raindropInstance.signUpDelegatedUser(
      delegatedUser.name, delegatedUser.public, signature.v, signature.r, signature.s, {from: owner.public}
    )
  })

  it('delegated user details are correct', async function () {
    let userNameTaken = await raindropInstance.userNameTaken(delegatedUser.name)
    assert.isTrue(userNameTaken, 'delegated user signed up incorrectly')
    let userDetailsByName = await raindropInstance.getUserByName(delegatedUser.name)
    assert.equal(userDetailsByName[0], delegatedUser.public, 'delegated user address stored incorrectly')
    assert.equal(userDetailsByName[1], true, 'delegated status stored incorrectly')
    let userDetailsByAddress = await raindropInstance.getUserByAddress(delegatedUser.public)
    assert.equal(userDetailsByAddress[0], delegatedUser.name, 'delegated user name stored incorrectly')
    assert.equal(userDetailsByAddress[1], true, 'delegated status stored incorrectly')
  })

  it('all added user names should be locked', async function () {
    let lockedNames = [user.name, delegatedUser.name]

    let userSignUpPromises = lockedNames.map(lockedName => {
      return raindropInstance.signUpUser.call(lockedName, {from: maliciousAdder.public})
        .then(() => { assert.fail('', '', 'user should not have been signed up') })
        .catch(() => {})
    })
    await Promise.all(userSignUpPromises)

    let delegatedUserSignUpPromises = signingMethods.map(method => {
      return sign(permissionString, delegatedUser, method)
        .then(signature => {
          raindropInstance.signUpDelegatedUser.call(
            delegatedUser.name, delegatedUser.public, signature.v, signature.r, signature.s, {from: maliciousAdder.public}
          )
            .then(() => { assert.fail('', '', 'user should not have been signed up') })
            .catch(() => {})
        })
        .catch(e => { assert.fail('', '', 'signature error') })
    })
    await Promise.all(delegatedUserSignUpPromises)
  })

  it('all addresses with existing accounts should not be able to add another', async function () {
    let newName = 'Alter Ego'
    let userPromise = raindropInstance.signUpUser(newName, {from: user.public})
      .then(() => { assert.fail('', '', 'user should not have been signed up') })
      .catch(() => {})
    let delegatedUserPromise = raindropInstance.signUpUser(newName, {from: delegatedUser.public})
      .then(() => { assert.fail('', '', 'user should not have been signed up') })
      .catch(() => {})
    await Promise.all([userPromise, delegatedUserPromise])
  })

  let challengeString = '123456'
  let challengeStringHash = web3.utils.keccak256(challengeString)

  it('should be able to recover signed messages', async function () {
    let signers = [user, delegatedUser]
    signers.forEach(async signer => {
      signingMethods.forEach(async method => {
        let signature = await sign(challengeString, signer, method)
        let isSigned = await raindropInstance.isSigned.call(
          signer.public, challengeStringHash, signature.v, signature.r, signature.s
        )
        assert.isTrue(isSigned, 'address signature unconfirmed')
      })
    })
  })

  it('users deleted', async function () {
    await raindropInstance.deleteUser({from: user.public})
    await raindropInstance.deleteUser({from: delegatedUser.public})
  })
})

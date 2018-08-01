const common = require('./common.js')
const Web3 = require('web3') // 1.0.0-beta.34
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')
const DummyResolver = artifacts.require('./resolvers/DummyResolver.sol')

contract('Clean Room', function (accounts) {
  const owner = {
    public: accounts[0]
  }
  var user1 = {
    hydroID: 'abcdefg',
    public: accounts[1],
    private: '6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
  }
  var user2 = {
    hydroID: 'tuvwxyz',
    public: accounts[2],
    private: 'ccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
  }
  var user3 = {
    public: accounts[3]
  }

  var instances

  it('common contracts deployed', async () => {
    instances = await common.initialize(owner.public, [user1, user2])
  })

  describe('Test snowflake functionality', async () => {
    it('mint identity token for user 1', async () => {
      let hasToken = await instances.snowflake.hasToken.call(user1.public)
      assert.equal(hasToken, false)

      instances.snowflake.getHydroId.call(user1.public)
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })

      let permission = await common.sign(web3.utils.soliditySha3('Create Snowflake', user1.public), user1, 'unprefixed')

      await instances.snowflake.mintIdentityTokenDelegated(
        user1.public, permission.v, permission.r, permission.s, { from: owner.public }
      )
    })

    it('have user 2 mint their own token', async () => {
      let hasToken = await instances.snowflake.hasToken.call(user2.public)
      assert.equal(hasToken, false)

      await instances.snowflake.getHydroId.call(user2.public)
        .then(() => { assert.fail('', '', 'application should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })

      await instances.snowflake.mintIdentityToken({ from: user2.public })
    })

    it('neither user should be able to mint now', async () => {
      [user1, user2].map(async user => {
        await instances.snowflake.mintIdentityToken.call(user.public)
          .then(() => { assert.fail('', '', 'signup should have been rejected') })
          .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
      })
    })

    it('verify token details', async () => {
      [user1, user2].map(async user => {
        let tokenDetails = await instances.snowflake.getDetails.call(user.hydroID)
        assert.equal(tokenDetails[0], user.public)
        assert.deepEqual(tokenDetails[1], [])
        assert.deepEqual(tokenDetails[2], [user.public])

        let ownsAddress = await instances.snowflake.ownsAddress.call(user.hydroID, user.public)
        assert.isTrue(ownsAddress)

        let hydroIdOfAddress = await instances.snowflake.getHydroId.call(user.public)
        assert.equal(hydroIdOfAddress, user.hydroID)
      })
    })
  })

  describe('Checking Resolver Functionality', async () => {
    it('deploy dummy resolver', async () => {
      let dummyResolver = await DummyResolver.new({ from: owner.public })
      instances.dummyResolver = dummyResolver
      await instances.dummyResolver.setSnowflakeAddress(instances.snowflake.address, { from: owner.public })
    })

    it('can whitelist a Resolver', async () => {
      await instances.snowflake.whitelistResolver(instances.dummyResolver.address, { from: user1.public })
      let isWhitelisted = await instances.snowflake.isWhitelisted(instances.dummyResolver.address)
      assert.isTrue(isWhitelisted, 'Unsuccessful whitelist.')

      let whitelistedResolvers = await instances.snowflake.getWhitelistedResolvers()
      assert.deepEqual(whitelistedResolvers, [instances.dummyResolver.address], 'Incorrect whitelist.')
    })

    it('can add a Resolver', async () => {
      var hasResolver = await instances.snowflake.hasResolver(user1.hydroID, instances.dummyResolver.address)
      assert.isFalse(hasResolver, 'Resolver exists without having been added.')

      await instances.snowflake.addResolvers([instances.dummyResolver.address], [1 * 1e18], { from: user1.public })

      hasResolver = await instances.snowflake.hasResolver(user1.hydroID, instances.dummyResolver.address)
      assert.isTrue(hasResolver, 'Resolver doesn\t exist after being added.')
    })

    it('can change Resolver balances', async () => {
      var allowance = await instances.snowflake.getResolverAllowance(user1.hydroID, instances.dummyResolver.address)
      assert.equal(allowance.toString(), 1e18, 'Resolver has an incorrect.')

      await instances.snowflake.changeResolverAllowances([instances.dummyResolver.address], [100 * 1e18], { from: user1.public })

      allowance = await instances.snowflake.getResolverAllowance(user1.hydroID, instances.dummyResolver.address)
      assert.equal(allowance.toString(), 100 * 1e18, 'Resolver doesn\t have an allowance.')
    })
  })

  describe('Checking HYDRO Functionality', async () => {
    it('can deposit HYDRO', async () => {
      await instances.token.approveAndCall(instances.snowflake.address, 110 * 1e18, '0x0', { from: user1.public })
      let snowflakeBalance = await instances.snowflake.snowflakeBalance(user1.hydroID)
      assert.equal(snowflakeBalance, 110 * 1e18, 'Incorrect balance')
    })

    it('can withdraw HYDRO', async () => {
      await instances.snowflake.withdrawSnowflakeBalanceTo(user1.public, 10 * 1e18, { from: user1.public })
      let snowflakeBalance = await instances.snowflake.snowflakeBalance(user1.hydroID)
      assert.equal(snowflakeBalance, 100 * 1e18, 'Incorrect balance')
    })

    it('can transfer HYDRO', async () => {
      await instances.snowflake.transferSnowflakeBalance(user2.hydroID, 50 * 1e18, { from: user1.public })
      let snowflakeBalance1 = await instances.snowflake.snowflakeBalance(user1.hydroID)
      let snowflakeBalance2 = await instances.snowflake.snowflakeBalance(user2.hydroID)
      assert.equal(snowflakeBalance1, 50 * 1e18, 'Incorrect balance')
      assert.equal(snowflakeBalance2, 50 * 1e18, 'Incorrect balance')
    })

    it('resolver can extract HYDRO', async () => {
      await instances.dummyResolver.withdrawFrom(user1.hydroID, 101 * 1e18, { from: owner.public })
        .then(() => { assert.fail('', '', 'withdraw should have been rejected') })
        .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })

      await instances.dummyResolver.withdrawFrom(user1.hydroID, 50 * 1e18, { from: owner.public })

      let snowflakeBalance = await instances.snowflake.snowflakeBalance(user1.hydroID)
      assert.equal(snowflakeBalance, 0, 'Incorrect balance')

      let allowance = await instances.snowflake.getResolverAllowance(user1.hydroID, instances.dummyResolver.address)
      assert.equal(allowance.toString(), 50 * 1e18, 'Incorrect allowance')
    })

    it('can remove resolvers', async () => {
      await instances.snowflake.removeResolvers([instances.dummyResolver.address], { from: user1.public })
    })
  })

  describe('Checking Address Ownership', async () => {
    it('claim user3 from user1', async () => {
      let secret = web3.utils.soliditySha3('shhhh')

      var claim = await web3.utils.soliditySha3(user3.public, secret, user1.hydroID)
      let permission = await common.sign(web3.utils.soliditySha3('Initiate Claim', claim), user1, 'unprefixed')

      await instances.snowflake.initiateClaimFor(
        user1.hydroID, claim, permission.v, permission.r, permission.s, { from: owner.public }
      )

      await instances.snowflake.finalizeClaim(secret, user1.hydroID, { from: user3.public })

      let ownsAddress = await instances.snowflake.ownsAddress.call(user1.hydroID, user3.public)
      assert.isTrue(ownsAddress)
    })
  })
})

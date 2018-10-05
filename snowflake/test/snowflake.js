const common = require('./common.js')
const Web3 = require('web3')
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')
const TestingResolver = artifacts.require('./_testing/TestingResolver.sol')
const TestingVia = artifacts.require('./_testing/TestingVia.sol')

function timeTravel (seconds) {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [seconds],
      id: new Date().getTime()
    }, (err, result) => {
      if (err) { return reject(err) }
      return resolve(result)
    })
  })
}

contract('Clean Room', function (accounts) {
  const owner = {
    public: accounts[0]
  }

  const users = [
    {
      hydroId: 'abcdefg',
      public: accounts[1],
      private: '6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
    },
    {
      hydroId: 'tuvwxyz',
      public: accounts[2],
      private: 'ccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
    },
    {
      public: accounts[3]
    },
    {
      public: accounts[4]
    }
  ]

  var instances

  it('common contracts deployed', async () => {
    instances = await common.initialize(owner.public, users.slice(0, 2))
  })

  describe('Test snowflake functionality', async () => {
    it('mint identity token for first user', async () => {
      let hasToken = await instances.snowflake.hasToken.call(users[0].public)
      assert.equal(hasToken, false)

      instances.snowflake.getHydroId.call(users[0].public)
        .then(() => { throw Error('application should have been rejected') })
        .catch(() => {})

      let permission = await common.sign(web3.utils.soliditySha3('Create Snowflake', users[0].public), users[0], 'unprefixed')

      await instances.snowflake.mintIdentityTokenDelegated(
        users[0].public, permission.v, permission.r, permission.s, { from: owner.public }
      )
    })

    it('have second user mint their own token', async () => {
      let hasToken = await instances.snowflake.hasToken.call(users[1].public)
      assert.equal(hasToken, false)

      await instances.snowflake.getHydroId.call(users[1].public)
        .then(() => { throw Error('application should have been rejected') })
        .catch(() => {})

      await instances.snowflake.mintIdentityToken({ from: users[1].public })
    })

    it('neither user should be able to mint now', async () => {
      users.slice(0, 2).map(async user => {
        await instances.snowflake.mintIdentityToken.call(user.public)
          .then(() => { throw Error('signup should have been rejected') })
          .catch(() => {})
      })
    })

    it('verify token details', async () => {
      users.slice(0, 2).map(async user => {
        let tokenDetails = await instances.snowflake.getDetails.call(user.hydroId)
        assert.equal(tokenDetails[0], user.public)
        assert.deepEqual(tokenDetails[1], [])
        assert.deepEqual(tokenDetails[2], [user.public])

        let ownsAddress = await instances.snowflake.ownsAddress.call(user.hydroId, user.public)
        assert.isTrue(ownsAddress)

        let hydroIdOfAddress = await instances.snowflake.getHydroId.call(user.public)
        assert.equal(hydroIdOfAddress, user.hydroId)
      })
    })
  })

  describe('Checking Resolver Functionality', async () => {
    it('deploy test resolver', async () => {
      instances.TestingResolver = await TestingResolver.new(instances.snowflake.address, { from: owner.public })
    })

    it('test is whitelisted', async () => {
      const isWhitelisted = await instances.snowflake.isWhitelisted(instances.TestingResolver.address)
      assert.isTrue(isWhitelisted, 'Unsuccessfully whitelisted.')

      const whitelistedResolvers = await instances.snowflake.getWhitelistedResolvers()
      assert.deepEqual(whitelistedResolvers, [instances.TestingResolver.address], 'Incorrect whitelist.')
    })

    it('first user can add test resolver', async () => {
      var hasResolver = await instances.snowflake.hasResolver(users[0].hydroId, instances.TestingResolver.address)
      assert.isFalse(hasResolver, 'Resolver exists without having been added.')

      const allowance = web3.utils.toBN(1e18)
      await instances.snowflake.addResolvers(
        [instances.TestingResolver.address], [allowance], { from: users[0].public }
      )

      hasResolver = await instances.snowflake.hasResolver(users[0].hydroId, instances.TestingResolver.address)
      assert.isTrue(hasResolver, 'Resolver does not exist after being added.')

      const actualAllowance = await instances.snowflake.getResolverAllowance(
        users[0].hydroId, instances.TestingResolver.address
      )

      assert.isTrue(actualAllowance.eq(allowance), 'Resolver has an incorrect allowance.')
    })

    it('second user can have test resolver added delegated', async () => {
      var hasResolver = await instances.snowflake.hasResolver(users[1].hydroId, instances.TestingResolver.address)
      assert.isFalse(hasResolver, 'Resolver exists without having been added.')

      const allowance = web3.utils.toBN(1e18).mul(web3.utils.toBN(2))
      const timestamp = Math.round(new Date() / 1000)
      const permissionString = await web3.utils.soliditySha3(
        'Add Resolvers',
        {t: 'address[]', v: [instances.TestingResolver.address]},
        {t: 'uint[]', v: [allowance]},
        timestamp
      )
      const permission = await common.sign(permissionString, users[1], 'unprefixed')

      await instances.snowflake.addResolversDelegated(
        users[1].hydroId,
        [instances.TestingResolver.address],
        [allowance],
        permission.v,
        permission.r,
        permission.s,
        timestamp,
        { from: owner.public }
      )

      hasResolver = await instances.snowflake.hasResolver(users[1].hydroId, instances.TestingResolver.address)
      assert.isTrue(hasResolver, 'Resolver does not exist after being added.')

      // after time traveling, signature is denied for the right reason
      timeTravel(7201)
      await instances.snowflake.addResolversDelegated(
        users[1].hydroId,
        [instances.TestingResolver.address],
        [allowance],
        permission.v,
        permission.r,
        permission.s,
        timestamp,
        { from: owner.public }
      )
        .then(() => { throw Error('should have been rejected') })
        .catch(error => { assert.include(error.message, 'Message was signed too long ago', 'wrong rejection reason') })
    })

    it('first user can change resolver allowance', async () => {
      const newAllowance = web3.utils.toBN(100).mul(web3.utils.toBN(1e18))
      await instances.snowflake.changeResolverAllowances(
        [instances.TestingResolver.address], [newAllowance], { from: users[0].public }
      )

      const setAllowance = await instances.snowflake.getResolverAllowance(
        users[0].hydroId, instances.TestingResolver.address
      )
      assert.isTrue(newAllowance.eq(setAllowance), 'Resolver has an incorrect allowance.')
    })

    it('second user can change resolver allowances delegated', async () => {
      const newAllowance = web3.utils.toBN(1e18)
      const timestamp = Math.round(new Date() / 1000)
      const permissionString = await web3.utils.soliditySha3(
        'Change Resolver Allowances',
        {t: 'address[]', v: [instances.TestingResolver.address]},
        {t: 'uint[]', v: [newAllowance]},
        timestamp
      )
      const permission = await common.sign(permissionString, users[1], 'unprefixed')

      await instances.snowflake.changeResolverAllowancesDelegated(
        users[1].hydroId,
        [instances.TestingResolver.address],
        [newAllowance],
        permission.v,
        permission.r,
        permission.s,
        timestamp,
        { from: owner.public }
      )

      const setAllowance = await instances.snowflake.getResolverAllowance(
        users[1].hydroId, instances.TestingResolver.address
      )
      assert.isTrue(newAllowance.eq(setAllowance), 'Resolver has an incorrect allowance.')

      // the same signature doesn't work twice
      await instances.snowflake.changeResolverAllowancesDelegated(
        users[1].hydroId,
        [instances.TestingResolver.address],
        [newAllowance],
        permission.v,
        permission.r,
        permission.s,
        timestamp,
        { from: owner.public }
      )
        .then(() => { throw Error('should have been rejected') })
        .catch(error => { assert.include(error.message, 'Signature was already submitted', 'wrong rejection reason') })
    })
  })

  describe('Checking HYDRO Functionality', async () => {
    it('deploy test via and fund it', async () => {
      instances.TestingVia = await TestingVia.new(
        instances.snowflake.address, instances.token.address, { from: owner.public }
      )

      instances.TestingVia.fund({from: owner.public, value: web3.utils.toWei('2', 'ether')})
    })

    it('can deposit HYDRO', async () => {
      const depositAmount = web3.utils.toBN(101).mul(web3.utils.toBN(1e18))
      await instances.token.approveAndCall(
        instances.snowflake.address, depositAmount, '0x00', { from: users[0].public }
      )
      let snowflakeBalance = await instances.snowflake.snowflakeBalance(users[0].hydroId)
      assert.isTrue(snowflakeBalance.eq(depositAmount), 'Incorrect balance')
    })

    it('can deposit HYDRO on behalf of', async () => {
      const depositAmount = web3.utils.toBN(1e18)
      await instances.token.approveAndCall(
        instances.snowflake.address, depositAmount, users[1].public, { from: users[0].public }
      )
      let snowflakeBalance = await instances.snowflake.snowflakeBalance(users[1].hydroId)
      assert.isTrue(snowflakeBalance.eq(depositAmount), 'Incorrect balance')
    })

    it('can transfer HYDRO from 1 snowflake to another', async () => {
      const transferAmount = web3.utils.toBN(1e18)
      await instances.snowflake.transferSnowflakeBalance(users[1].hydroId, transferAmount, { from: users[0].public })

      let remainingBalance = await instances.snowflake.snowflakeBalance(users[0].hydroId)
      assert.isTrue(remainingBalance.eq(web3.utils.toBN(100).mul(web3.utils.toBN(1e18))), 'Incorrect balance')

      let newBalance = await instances.snowflake.snowflakeBalance(users[1].hydroId)
      assert.isTrue(newBalance.eq(web3.utils.toBN(2).mul(web3.utils.toBN(1e18))), 'Incorrect balance')
    })

    it('can withdraw HYDRO', async () => {
      const originalBalance = await instances.token.balanceOf(users[1].public)
      const snowflakeBalance = await instances.snowflake.snowflakeBalance(users[1].hydroId)

      await instances.snowflake.withdrawSnowflakeBalance(users[1].public, snowflakeBalance, { from: users[1].public })
      const newBalance = await instances.token.balanceOf(users[1].public)

      assert.isTrue(newBalance.eq(originalBalance.add(snowflakeBalance)), 'Incorrect balance')
    })

    it('resolver can transfer balances from', async () => {
      const amount = web3.utils.toBN(1e18).mul(web3.utils.toBN(10))

      const snowflakeBalance = await instances.snowflake.snowflakeBalance(users[1].hydroId)

      await instances.TestingResolver.transferSnowflakeBalanceFrom(
        users[0].hydroId, users[1].hydroId, amount, { from: owner.public }
      )

      const newSnowflakeBalance = await instances.snowflake.snowflakeBalance(users[1].hydroId)
      assert.isTrue(newSnowflakeBalance.eq(snowflakeBalance.add(amount)), 'Incorrect balance')
    })

    it('resolver can withdraw balances from', async () => {
      // try withdrawing twice from second user, should fail the second time, because of InsufficientAllowance
      const amount = web3.utils.toBN(1e18)
      await instances.TestingResolver.withdrawSnowflakeBalanceFrom(
        users[1].hydroId, owner.public, amount, { from: owner.public }
      )

      await instances.TestingResolver.withdrawSnowflakeBalanceFrom(
        users[1].hydroId, owner.public, amount, { from: owner.public }
      )
        .then(() => { throw Error('withdraw should have been rejected') })
        .catch(error => { assert.include(error.message, 'Insufficient Allowance', 'wrong rejection reason') })
    })

    it('resolver can withdraw balances from via, hydroId', async () => {
      const amount = web3.utils.toBN(1e18).mul(web3.utils.toBN(10))
      await instances.TestingResolver.methods['withdrawSnowflakeBalanceFromVia(string,address,string,uint256)'](
        users[0].hydroId, instances.TestingVia.address, users[1].hydroId, amount, { from: owner.public }
      )
      const originalBalance = await web3.eth.getBalance(owner.public)
      await instances.TestingVia.withdrawTo(owner.public, { from: users[1].public })
      const newBalance = await web3.eth.getBalance(owner.public)

      // only 1 because we sent 10 hydro := 1 eth as defined in the via contract
      assert.isTrue(
        web3.utils.toBN(newBalance).eq(web3.utils.toBN(originalBalance).add(web3.utils.toBN(1e18))),
        'Incorrect balance'
      )
    })

    it('resolver can withdraw balances from via, address', async () => {
      const amount = web3.utils.toBN(1e18).mul(web3.utils.toBN(10))
      const originalBalance = await web3.eth.getBalance(users[1].public)

      await instances.TestingResolver.methods['withdrawSnowflakeBalanceFromVia(string,address,address,uint256)'](
        users[0].hydroId, instances.TestingVia.address, users[1].public, amount, { from: owner.public }
      )

      const newBalance = await web3.eth.getBalance(users[1].public)
      // only 1 because we sent 10 hydro := 1 eth as defined in the via contract
      assert.isTrue(
        web3.utils.toBN(newBalance).eq(web3.utils.toBN(originalBalance).add(web3.utils.toBN(1e18))),
        'Incorrect balance'
      )
    })

    it('via owner can withdraw hydro', async () => {
      const originalBalance = await instances.token.balanceOf(owner.public)
      const amount = await instances.token.balanceOf(instances.TestingVia.address)
      instances.TestingVia.withdrawHydroTo(owner.public, { from: owner.public })
      const newBalance = await instances.token.balanceOf(owner.public)

      assert.isTrue(newBalance.eq(originalBalance.add(amount)), 'Incorrect balance')
    })
  })

  describe('Checking Address Ownership', async () => {
    it('claim users[2] from users[0], delegated', async () => {
      let secret = web3.utils.soliditySha3('sh')

      var claim = await web3.utils.soliditySha3(users[2].public, secret, users[0].hydroId)
      let permission = await common.sign(web3.utils.soliditySha3('Initiate Claim', claim), users[0], 'unprefixed')

      await instances.snowflake.initiateClaimDelegated(
        users[0].hydroId, claim, permission.v, permission.r, permission.s, { from: owner.public }
      )

      await instances.snowflake.finalizeClaim(secret, users[0].hydroId, { from: users[2].public })

      let ownsAddress = await instances.snowflake.ownsAddress.call(users[0].hydroId, users[2].public)
      assert.isTrue(ownsAddress)
    })

    it('fail to claim claim users[2] from users[1]', async () => {
      let secret = web3.utils.soliditySha3('shh')

      var claim = await web3.utils.soliditySha3(users[2].public, secret, users[1].hydroId)

      await instances.snowflake.initiateClaim(claim, { from: users[1].public })

      await instances.snowflake.finalizeClaim(secret, users[1].hydroId, { from: users[2].public })
        .then(() => { throw Error('finalization should have been rejected') })
        .catch(() => {})
    })

    it('claim users[3] from users[1]', async () => {
      let secret = web3.utils.soliditySha3('shhh')

      var claim = await web3.utils.soliditySha3(users[3].public, secret, users[1].hydroId)

      await instances.snowflake.initiateClaim(claim, { from: users[1].public })

      await instances.snowflake.finalizeClaim(secret, users[1].hydroId, { from: users[3].public })

      let ownsAddress = await instances.snowflake.ownsAddress.call(users[1].hydroId, users[3].public)
      assert.isTrue(ownsAddress)
    })

    it('unclaim users[3] from users[1]', async () => {
      await instances.snowflake.unclaim([users[3].public], { from: users[1].public })
    })
  })

  describe('Cleaning Up', async () => {
    it('second user cannot remove resolver normally, but can by force', async () => {
      await instances.snowflake.removeResolvers([instances.TestingResolver.address], false, { from: users[1].public })
        .then(() => { throw Error('removal should not have gone through') })
        .catch(() => {})

      await instances.snowflake.removeResolvers([instances.TestingResolver.address], true, { from: users[1].public })

      const hasResolver = await instances.snowflake.hasResolver(users[1].hydroId, instances.TestingResolver.address)
      assert.isFalse(hasResolver, 'resolver was not removed')
    })
  })
})

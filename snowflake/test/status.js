const common = require('./common.js')
const Web3 = require('web3')
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')
const Status = artifacts.require('./resolvers/Status.sol')

contract('Clean Room', function (accounts) {
  const owner = {
    public: accounts[0]
  }

  const users = [
    {
      hydroId: 'abcdefg',
      public: accounts[1],
      private: '6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
    }
  ]

  var instances

  it('common contracts deployed', async () => {
    instances = await common.initialize(owner.public, users)
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

    it('can deposit HYDRO', async () => {
      const depositAmount = web3.utils.toBN(1e18).mul(web3.utils.toBN(2))
      await instances.token.approveAndCall(
        instances.snowflake.address, depositAmount, '0x00', { from: users[0].public }
      )
      let snowflakeBalance = await instances.snowflake.snowflakeBalance(users[0].hydroId)
      assert.isTrue(snowflakeBalance.eq(depositAmount), 'Incorrect balance')
    })
  })

  describe('Checking Resolver Functionality', async () => {
    it('deploy Status', async () => {
      instances.Status = await Status.new(instances.snowflake.address, { from: owner.public })
    })

    it('first user can add status', async () => {
      var hasResolver = await instances.snowflake.hasResolver(users[0].hydroId, instances.Status.address)
      assert.isFalse(hasResolver, 'Resolver exists without having been added.')

      const allowance = web3.utils.toBN(1e18)
      await instances.snowflake.addResolvers(
        [instances.Status.address], [allowance], { from: users[0].public }
      )

      // check resolver is set
      hasResolver = await instances.snowflake.hasResolver(users[0].hydroId, instances.Status.address)
      assert.isTrue(hasResolver, 'Resolver does not exist after being added.')

      // check allowance
      const actualAllowance = await instances.snowflake.getResolverAllowance(
        users[0].hydroId, instances.Status.address
      )

      assert.isTrue(actualAllowance.eq(web3.utils.toBN(0)), 'Resolver has an incorrect allowance.')
    })
  })
})

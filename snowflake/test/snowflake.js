const common = require('./common.js')
const { sign, verifyIdentity } = require('./utilities')

let user
let instances
contract('Testing Snowflake', function (accounts) {
  const users = [
    {
      hydroID: 'abc',
      address: accounts[1],
      recoveryAddress: accounts[1],
      private: '0x6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
    },
    {
      hydroID: 'xyz',
      address: accounts[2],
      recoveryAddress: accounts[2],
      private: '0xccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
    },
    {
      public: accounts[3]
    },
    {
      public: accounts[4]
    }
  ]

  it('common contracts deployed', async () => {
    instances = await common.initialize(accounts[0], [])
  })

  describe('Test Snowflake', async () => {
    it('Identity can be created', async function () {
      user = users[0]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize the creation of an Identity on my behalf.',
        user.recoveryAddress,
        user.address,
        { t: 'address[]', v: [instances.Snowflake.address] },
        { t: 'address[]', v: [] },
        timestamp
      )

      const permission = await sign(permissionString, user.address, user.private)

      await instances.Snowflake.createIdentityDelegated(
        user.recoveryAddress, user.address, [], user.hydroID, permission.v, permission.r, permission.s, timestamp
      )

      user.identity = web3.utils.toBN(1)

      await verifyIdentity(user.identity, instances.IdentityRegistry, {
        recoveryAddress:     user.recoveryAddress,
        associatedAddresses: [user.address],
        providers:           [instances.Snowflake.address],
        resolvers:           [instances.ClientRaindrop.address]
      })
    })
  })

  describe('Testing Client Raindrop', async () => {
    const newStake = web3.utils.toBN(1).mul(web3.utils.toBN(1e18))
    it('Stakes are settable', async function () {
      await instances.ClientRaindrop.setStakes(newStake, newStake)
    })

    it('Insufficiently staked provider sign-ups are rejected', async function () {
      user = users[1]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize the creation of an Identity on my behalf.',
        user.recoveryAddress,
        user.address,
        { t: 'address[]', v: [instances.Snowflake.address] },
        { t: 'address[]', v: [] },
        timestamp
      )

      const permission = await sign(permissionString, user.address, user.private)

      await instances.Snowflake.createIdentityDelegated(
        user.recoveryAddress, user.address, [], user.hydroID, permission.v, permission.r, permission.s, timestamp,
        { from: user.address }
      )
        .then(() => assert.fail('unstaked HydroID was reserved', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'Insufficient staked HYDRO balance.', 'unexpected error'))
    })

    it('Could sign up as staked provider', async function () {
      user = users[1]
      const timestamp = Math.round(new Date() / 1000) - 1
      const permissionString = web3.utils.soliditySha3(
        '0x19', '0x00', instances.IdentityRegistry.address,
        'I authorize the creation of an Identity on my behalf.',
        user.recoveryAddress,
        user.address,
        { t: 'address[]', v: [instances.Snowflake.address] },
        { t: 'address[]', v: [] },
        timestamp
      )

      const permission = await sign(permissionString, user.address, user.private)

      await instances.Snowflake.createIdentityDelegated.call(
        user.recoveryAddress, user.address, [], user.hydroID, permission.v, permission.r, permission.s, timestamp
      )
    })

    it('User 1 can sign up for an identity and add client raindrop', async function () {
      await instances.IdentityRegistry.createIdentity(
        user.recoveryAddress, [], [instances.ClientRaindrop.address], { from: user.address }
      )
    })

    it('Insufficiently staked self signups are rejected', async function () {
      await instances.ClientRaindrop.signUp(user.address, user.hydroID, { from: user.address })
        .then(() => assert.fail('unstaked HydroID was reserved', 'transaction should fail'))
        .catch(error => assert.include(error.message, 'Insufficient staked HYDRO balance.', 'unexpected error'))

      await instances.HydroToken.transfer(user.address, newStake, { from: accounts[0] })
    })

    it('Bad HydroIDs are rejected', async function () {
      user = users[1]
      const badHydroIDs = ['Abc', 'aBc', 'abC', 'ABc', 'AbC', 'aBC', 'ABC', '1', '12', 'a'.repeat(33)]

      await Promise.all(badHydroIDs.map(badHydroID => {
        return instances.ClientRaindrop.signUp(user.address, badHydroID, { from: user.address })
          .then(() => assert.fail('bad HydroID was reserved', 'transaction should fail'))
          .catch(error => assert.match(
            error.message, /.*HydroID is unavailable\.|HydroID has invalid length\..*/, 'unexpected error'
          ))
      }))
    })

    it('could sign up self once conditions are met', async function () {
      await instances.ClientRaindrop.signUp.call(user.address, user.hydroID, { from: user.address })
    })
  })
})

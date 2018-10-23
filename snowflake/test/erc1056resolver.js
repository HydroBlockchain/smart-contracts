const Web3 = require('web3')
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

const common = require('./common.js')
const { sign, verifyIdentity } = require('./utilities')

let instances

contract('Testing ERC1056 Resolver', function (accounts) {
  const users = [
    {
      hydroID: 'xyz',
      address: accounts[1],
      recoveryAddress: accounts[1],
      private: '0x6bf410ff825d07346c110c5836b33ec76e7d1ee051283937392180b732aa3aff'
    },
    {
      hydroID: 'abc',
      address: accounts[2],
      recoveryAddress: accounts[2],
      private: '0xccc3c84f02b038a5d60d93977ab11eb57005f368b5f62dad29486edeb4566954'
    }
  ]

  it('common contracts deployed', async () => {
    instances = await common.initialize(accounts[0], [])
  })

  describe('Mint Snowflake', async () => {
    it('Identity minted', async function () {
      const user = users[0]

      const permissionString = web3.utils.soliditySha3(
        'Mint',
        instances.IdentityRegistry.address,
        user.recoveryAddress,
        user.address,
        instances.Snowflake.address,
        { t: 'address[]', v: [] }
      )

      const permission = await sign(permissionString, user.address, user.private)

      await instances.Snowflake.methods['mintIdentityDelegated(address,address,address[],uint8,bytes32,bytes32)'](
        user.recoveryAddress, user.address, [],
        permission.v, permission.r, permission.s
      )

      user.identity = web3.utils.toBN(1)

      await verifyIdentity(user.identity, instances.IdentityRegistry, {
        recoveryAddress:     user.recoveryAddress,
        associatedAddresses: [user.address],
        providers:           [instances.Snowflake.address],
        resolvers:           []
      })
    })
  })

  describe('initialize', async () => {
    it('1056 owner changed', async function () {
      const permissionString = web3.utils.soliditySha3(
        { t: 'bytes1', v: '0x19'},
        { t: 'bytes1', v: 0},
        instances.EthereumDIDRegistry.address,
        0,
        user.identity,
        "changeOwner",
        instances.Erc1056.address
      )

      const permission = await sign(permissionString, user.address, user.private)

      await instances.Erc1056.initialize(user.identity, permission.v, permission.r, permission.s)
    })
  })

})

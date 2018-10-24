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
        { t: 'address[]', v: [instances.Erc1056.address] }
      )

      const permission = await sign(permissionString, user.address, user.private)

      await instances.Snowflake.methods['mintIdentityDelegated(address,address,address[],uint8,bytes32,bytes32)'](
        user.recoveryAddress, user.address, [instances.Erc1056.address],
        permission.v, permission.r, permission.s
      )

      user.identity = web3.utils.toBN(1)

      await verifyIdentity(user.identity, instances.IdentityRegistry, {
        recoveryAddress:     user.recoveryAddress,
        associatedAddresses: [user.address],
        providers:           [instances.Snowflake.address],
        resolvers:           [instances.Erc1056.address]
      })
    })
  })

  describe('initialize', async () => {
    it('1056 owner changed', async function () {
      const user = users[0]

      const initializePermission = web3.utils.soliditySha3(
        { t: 'bytes1', v: '0x19'},
        { t: 'bytes1', v: '0'},
        instances.EthereumDIDRegistry.address,
        0,
        user.address,
        "changeOwner",
        instances.Erc1056.address
      )

      const permission = await sign(initializePermission, user.address, user.private, "unprefixed")

      await instances.Erc1056.initialize(user.address, permission.v, permission.r, permission.s, { from: user.address })
    })
  })

  describe('delegates normal', async () => {
    const user = users[0]
    const delegate = users[1]
    const randomBytes = web3.utils.soliditySha3("random")

    it('add delegate', async function () {
      await instances.Erc1056.addDelegate(randomBytes, delegate.address, 10000, { from:  user.address })
    })

    it('remove delegate', async function () {
      await instances.Erc1056.revokeDelegate(randomBytes, delegate.address, { from:  user.address })
    })
  })

  describe('delegates signed', async () => {
    const user = users[0]
    const delegate = users[1]
    const randomBytes = web3.utils.soliditySha3("random")

    it('add delegate signed', async function () {

      let nonce = await instances.Erc1056.actionNonce(user.identity)

      const permission = web3.utils.soliditySha3(
        "addDelegateDelegated",
        { t: 'bytes32', v: randomBytes},
        delegate.address,
        100000,
        nonce
      )

      const signature = await sign(permission, user.address, user.private, "unprefixed")

      await instances.Erc1056.addDelegateDelegated(randomBytes, delegate.address, 100000, signature.v, signature.r, signature.s, user.address, { from: user.address })
    })

    it('revoke delegate signed', async function () {

      let nonce = await instances.Erc1056.actionNonce(user.identity)

      const permission = web3.utils.soliditySha3(
        "revokeDelegateDelegated",
        { t: 'bytes32', v: randomBytes},
        delegate.address,
        nonce
      )

      const signature = await sign(permission, user.address, user.private, "unprefixed")

      await instances.Erc1056.revokeDelegateDelegated(randomBytes, delegate.address, signature.v, signature.r, signature.s, user.address, { from: user.address })

      nonce = await instances.Erc1056.actionNonce(user.identity)

      assert.equal(nonce.valueOf(), 2)
    })
  })

  describe('attributes normal', async () => {
    const user = users[0]
    const name = web3.utils.soliditySha3("name")
    const value = '0x01'

    it('add attribute', async function () {
      await instances.Erc1056.setAttribute(name, value, 10000, { from:  user.address })
    })

    it('remove attribute', async function () {
      await instances.Erc1056.revokeAttribute(name, value, { from:  user.address })
    })
  })

  describe('attributes signed', async () => {
    const user = users[0]
    const delegate = users[1]
    const name = web3.utils.soliditySha3("name")
    const value = '0x01'

    it('set attribute signed', async function () {

      let nonce = await instances.Erc1056.actionNonce(user.identity)

      const permission = web3.utils.soliditySha3(
        "setAttributeDelegated",
        { t: 'bytes32', v: name},
        { t: 'bytes', v: value},
        100000,
        nonce
      )

      const signature = await sign(permission, user.address, user.private, "unprefixed")

      await instances.Erc1056.setAttributeDelegated(name, value, 100000, signature.v, signature.r, signature.s, user.address, { from: user.address })
    })

    it('revoke attribute signed', async function () {

      let nonce = await instances.Erc1056.actionNonce(user.identity)

      const permission = web3.utils.soliditySha3(
        "revokeAttributeDelegated",
        { t: 'bytes32', v: name},
        { t: 'bytes', v: value},
        nonce
      )

      const signature = await sign(permission, user.address, user.private, "unprefixed")

      await instances.Erc1056.revokeAttributeDelegated(name, value, signature.v, signature.r, signature.s, user.address, { from: user.address })

      nonce = await instances.Erc1056.actionNonce(user.identity)

      assert.equal(nonce.valueOf(), 4)
    })
  })

})

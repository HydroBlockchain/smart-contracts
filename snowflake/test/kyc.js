// describe('KYC Tests', function () {
//   it('hydro kyc deployed', async function () {
//     instances.KYC = await HydroKYC.new({ from: owner.public })
//     await instances.KYC.setSnowflakeAddress(instances.snowflake.address)
//   })

//   var standard = web3.utils.keccak256('standard')
//   it('happy path tests', async function () {
//     await instances.KYC.addKYCStandard(standard, {from: user1.public})
//     await instances.KYC.attestToUsersKYC(standard, 1, {from: user2.public})

//     var count = await instances.KYC.getAttestationCountToUser(standard, 1, {from: user2.public})
//     assert.equal(count, 1)

//     var addresses = await instances.KYC.getAttestationsToUser(standard, 1, {from: user2.public})
//     assert.equal(addresses.length, 1)
//     assert.equal(addresses[0], user2.public)

//     var blockNumber = await instances.KYC.getTimeOfAttestation(standard, 1, user2.public, {from: user2.public})
//     assert.equal(blockNumber, await web3.eth.getBlockNumber())
//   })

//   it('standard already added', async function () {
//     await instances.KYC.addKYCStandard.call(standard, {from: user1.public})
//       .then(() => { assert.fail('', '', 'application should have been rejected') })
//       .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
//   })

//   it('snowflake doesnt exist', async function () {
//     await instances.KYC.attestToUsersKYC.call(standard, 100, {from: user2.public})
//       .then(() => { assert.fail('', '', 'application should have been rejected') })
//       .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
//   })

//   it('standard doesnt exist', async function () {
//     await instances.KYC.attestToUsersKYC.call(standard, 1, {from: user2.public})
//       .then(() => { assert.fail('', '', 'application should have been rejected') })
//       .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
//   })
// })

// describe('Hydro Reputation', function () {
//   it('hydro reputation deployed', async function () {
//     instances.reputation = await HydroReputation.new({ from: owner.public })
//     await instances.reputation.setSnowflakeAddress(instances.snowflake.address)
//   })

//   it('join hydro reputation', async function () {
//     await instances.reputation.joinHydroReputation({from: user1.public})
//     await instances.snowflake.mintIdentityToken(hashedNames, hashedDateOfBirth, { from: user2.public })
//     await instances.reputation.joinHydroReputation({from: user2.public})
//   })

//   it('add field and attest to field', async function () {
//     await instances.reputation.addReputationField('Hydro Is Awesome!!', {from: user1.public})
//     await instances.reputation.attestToReputation(user1.public, 'Hydro Is Awesome!!', { from: user2.public })
//   })

//   it('add duplicate field fail', async function () {
//     instances.reputation.addReputationField.call('Hydro Is Awesome!!', {from: user1.public})
//       .then(() => { assert.fail('', '', 'application should have been rejected') })
//       .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
//   })

//   it('attest duplicate field fail', async function () {
//     instances.reputation.attestToReputation.call(user1.public, 'Hydro Is Awesome!!', {from: user2.public})
//       .then(() => { assert.fail('', '', 'application should have been rejected') })
//       .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
//   })

//   it('get reputation for added field', async function () {
//     let repCount = await instances.reputation.getReputation.call(user1.public, 'Hydro Is Awesome!!', {from: user2.public})
//     assert.equal(repCount, 1)
//   })

//   it('get reputation list for added field', async function () {
//     let repList = await instances.reputation.getReputationList.call(user1.public, 'Hydro Is Awesome!!', {from: user2.public})
//     assert.equal(repList[0], user2.public)
//   })

//   it('get single reputation for added field', async function () {
//     let rep = await instances.reputation.getReputationIndividual.call(user1.public, 'Hydro Is Awesome!!', 0, {from: user2.public})
//     assert.equal(rep, user2.public)
//   })

//   it('get nonexistant rep fail', async function () {
//     instances.reputation.getReputationIndividual.call(user1.public, 'Hydro Is Awesome!!', 45, {from: user2.public})
//       .then(() => { assert.fail('', '', 'application should have been rejected') })
//       .catch(error => { assert.include(error.message, 'revert', 'unexpected error') })
//   })
// })
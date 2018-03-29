const Web3 = require('web3'); // 1.0.0-beta.33
const web3 = new Web3(Web3.givenProvider);

var BN = web3.utils.BN;
var Raindrop = artifacts.require("./Raindrop.sol");

contract('Raindrop', function(accounts) {
    const owner = {
        public:  accounts[0],
    }
    const user = {
        public:  accounts[1],
    };

    var instance;

    //////////////
    //  Basics  //
    //////////////

    it('raindrop deployed', async function () {
        instance = await Raindrop.new({from: owner.public});
    });

    /////////////////
    //  Whitelist  //
    /////////////////

    it('whitelist address', async function () {
        await instance.whitelistAddress(user.public, true, 1, {from: owner.public});
    });

    it('fail to whitelist not owner address', function () {
        return instance.whitelistAddress.call(user.public, true, 1, {from: user.public})
        .then(() => {assert.fail("", "", "application should have been rejected")})
        .catch(error => {assert.include(error.message, "revert", "unexpected error")})
    });

    /////////////////
    //  Hydro Map  //
    /////////////////

    it('update hydro map', async function () {
        await instance.updateHydroMap(user.public, 5, 1, {from: owner.public});
        let amount = await instance.checkForValidChallenge(user.public, 1, {from: owner.public});
        assert.equal(amount, 5, 'The valid challenge was wrong');
    })

    it('fail to update hydro map not owner address', function () {
        return instance.updateHydroMap.call(user.public, 5, 1, {from: user.public})
        .then(() => {assert.fail("", "", "application should have been rejected")})
        .catch(error => {assert.include(error.message, "revert", "unexpected error")})
    });

    /////////////////
    //  Challenge  //
    /////////////////

    it('fail to get a valid challenge', async function () {
        let amount = await instance.checkForValidChallenge(owner.public, 1, {from: owner.public});
        assert.equal(amount, 1, 'The valid challenge check was incorrect');
    })

    //////////////////////
    //  Authentication  //
    //////////////////////

    it('check for valid authentication false', async function () {
        let success = await instance.validateAuthentication.call(user.public, 1, 1, {from: owner.public});
        assert.equal(success, false, 'Authentication succeeded where it should have failed');
    })

});

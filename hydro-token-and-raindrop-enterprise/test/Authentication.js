const Web3 = require('web3'); // 1.0.0-beta.33
const web3 = new Web3(Web3.givenProvider);

var BN = web3.utils.BN;
var Raindrop = artifacts.require("./Raindrop.sol");
var HydroToken = artifacts.require("./HydroToken.sol");

contract('Joined', function(accounts) {
    const owner = {
        public:  accounts[0],
    }
    const user = {
        public:  accounts[1],
    };

    var instanceRaindrop;
    var instanceHydro;

    //////////////
    //  Deploy  //
    //////////////

    it('hydro deployed', async function () {
        instanceHydro = await HydroToken.new({from: owner.public});
    });

    it('raindrop deployed', async function () {
        instanceRaindrop = await Raindrop.new({from: owner.public});
    });

    it('set raindrop address', async function () {
        await instanceHydro.setRaindropAddress(instanceRaindrop.address, {from: owner.public});
    });

    it('set hydro address', async function () {
        await instanceRaindrop.setHydroContractAddress(instanceHydro.address, {from: owner.public});
    });

    ////////////////
    //  Raindrop  //
    ////////////////

    it('run through raindrop', async function () {
        await instanceRaindrop.whitelistAddress(user.public, true, 1, {from: owner.public});
        await instanceRaindrop.updateHydroMap(user.public, 5, 1, {from: owner.public});
        let amount = await instanceRaindrop.checkForValidChallenge(user.public, 1, {from: owner.public});
        assert.equal(amount, 5, 'The valid challenge was wrong');
        await instanceHydro.transfer(user.public, 100, {from: owner.public});
        await instanceHydro.authenticate(5, 1, 1, {from: user.public});
        let success = await instanceRaindrop.validateAuthentication(user.public, 1, 1, {from: owner.public});
        assert.equal(success, true, 'authentication failed');
    });

});

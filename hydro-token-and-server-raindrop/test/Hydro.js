const Web3 = require('web3'); // 1.0.0-beta.34
const web3 = new Web3(Web3.givenProvider || 'http://localhost:8555')

var BN = web3.utils.BN;
var HydroToken = artifacts.require("./HydroToken.sol");

contract('HydroToken', function(accounts) {
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

    it('hydro deployed', async function () {
        instance = await HydroToken.new({from: owner.public});
    });

    it('should have the name Hydro', async function () {
        let contractName = await instance.name();
        assert.equal(contractName, "Hydro", 'name is not correct');
    });

    it('should have the decimals 18', async function () {
        let decimals = await instance.decimals();
        assert.equal(decimals, 18, 'decimlas are not correct');
    });

    it('should have the symbol HYDRO', async function () {
        let contractSymbol = await instance.symbol();
        assert.equal(contractSymbol, "HYDRO", 'symbol is not correct');
    });

    it('should have the total supply of 11111111111000000000000000000', async function () {
        let totalSupply = await instance.totalSupply();
        assert.equal(totalSupply, 11111111111000000000000000000, 'supply is not correct');
    });

    it('owner should have all tokens', async function () {
        let ownerBalance = await instance.balanceOf(owner.public);
        assert.equal(ownerBalance, 11111111111000000000000000000, 'balance is not correct');
    });

    it('other should have no tokens', async function () {
        let balance = await instance.balanceOf(user.public);
        assert.equal(balance, 0, 'balance is not correct');
    });

    //////////////
    // Transfer //
    //////////////

    it('transfer tokens', async function () {
        let initialBalance = await instance.balanceOf(user.public);

        let success = await instance.transfer.call(user.public, 15, {from: owner.public});
        assert.equal(success, true, 'transfer failed');
        await instance.transfer(user.public, 15, {from: owner.public});

        let balance = await instance.balanceOf(user.public);
        assert.equal(balance, parseInt(initialBalance) + 15, 'balance is not correct after transfer');
    });

    it('fail to transfer tokens', function () {
        return instance.transfer.call(owner.public, 150, {from: user.public})
            .then(() => {assert.fail("", "", "application should have been rejected")})
            .catch(error => {assert.include(error.message, "revert", "unexpected error")});
    });

    ///////////////////
    // Transfer From //
    ///////////////////

    it('transfer from tokens', async function () {
        let success = await instance.approve.call(user.public, 15, {from: owner.public});
        assert.equal(success, true, 'approve failed');
        await instance.approve(user.public, 15, {from: owner.public});

        let initialBalance = await instance.balanceOf(user.public);

        let success2 = await instance.transferFrom.call(owner.public, user.public, 15, {from: user.public});
        assert.equal(success2, true, 'transfer from failed');
        await instance.transferFrom(owner.public, user.public, 15, {from: user.public});

        let balance = await instance.balanceOf(user.public);
        assert.equal(balance, parseInt(initialBalance) + 15, 'balance is not correct after transfer');
    });

    it('fail to transfer from tokens', function () {
      return instance.transferFrom.call(owner.public, user.public, 15000000, {from: user.public})
          .then(() => {assert.fail("", "", "application should have been rejected")})
          .catch(error => {assert.include(error.message, "revert", "unexpected error")});
    });

    //////////
    // Burn //
    //////////

    it('burn tokens', async function () {
        await instance.burn(15, {from: owner.public});
    });

    //////////////
    // Raindrop //
    //////////////

    it('set raindrop address', async function () {
        await instance.setRaindropAddress(user.public, {from: owner.public});
    });

});

var Hydro = artifacts.require("./HydroToken.sol");
var Raindrop = artifacts.require("./Raindrop.sol");

module.exports = function(deployer) {
    deployer.deploy(Hydro);
    deployer.deploy(Raindrop);
};

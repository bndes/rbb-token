var RBBLib = artifacts.require("./RBBLib.sol");
var RBBRegistry = artifacts.require("./RBBRegistry.sol");
var FABndesToken = artifacts.require("./FABndesToken.sol");

module.exports = async (deployer, network, accounts) => {

	deployer.deploy(RBBLib);
	deployer.link(RBBLib, RBBRegistry);
	deployer.deploy(RBBRegistry, accounts[0]);

	deployer.link(RBBLib, FABndesToken);
	deployer.deploy(FABndesToken, RBBRegistry.address, accounts[0], accounts[0] ); 
	
};

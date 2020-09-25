var RBBLib = artifacts.require("./RBBLib.sol");
var RBBRegistry = artifacts.require("./RBBRegistry.sol");
var RBBToken = artifacts.require("./RBBToken.sol");
var FABndesToken = artifacts.require("./FABndesToken.sol");

module.exports = async (deployer, network, accounts) => {

	await deployer.deploy(RBBLib);
	await deployer.link(RBBLib, RBBRegistry);
	await deployer.deploy(RBBRegistry, accounts[0]);

	RBBRegistryInstance = await RBBRegistry.deployed();
	await RBBRegistryInstance.registryMock("123456789");

	RBBTokenInstance = await deployer.deploy(RBBToken, RBBRegistry.address, 2); 

	deployer.link(RBBLib, FABndesToken);
	deployer.deploy(FABndesToken, RBBToken.address, 3); 
	
};

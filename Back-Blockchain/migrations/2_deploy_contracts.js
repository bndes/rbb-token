var RBBLib = artifacts.require("./RBBLib.sol");
var RBBRegistry = artifacts.require("./RBBRegistry.sol");
var RBBToken = artifacts.require("./RBBToken.sol");
var FABndesToken = artifacts.require("./FABndesToken.sol");
var GetDataToCallFABndesToken = artifacts.require("./GetDataToCallFABndesToken.sol");


module.exports = async (deployer, network, accounts) => {

	await deployer.deploy(RBBLib);
	await deployer.link(RBBLib, RBBRegistry);
	await deployer.link(RBBLib, FABndesToken);

	await deployer.deploy(RBBRegistry, accounts[0]);

	RBBRegistryInstance = await RBBRegistry.deployed();
	await RBBRegistryInstance.registryMock("123456789");

	RBBTokenInstance = await deployer.deploy(RBBToken, RBBRegistry.address, 2); 

	FABndesTokenInstance = await deployer.deploy(FABndesToken, RBBToken.address, 3); 

	GetDataToCallFABndesTokenInstance = await deployer.deploy(GetDataToCallFABndesToken, FABndesToken.address); 

	
};

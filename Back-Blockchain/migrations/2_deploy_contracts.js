var RBBLib = artifacts.require("./RBBLib.sol");
var RBBRegistry = artifacts.require("./RBBRegistry.sol");
var RBBToken = artifacts.require("./RBBToken.sol");
var FABndesToken = artifacts.require("./FABndesToken.sol");
var FABndesToken_BNDESRoles = artifacts.require("./FABndesToken_BNDESRoles.sol");
var FABndesToken_GetDataToCall = artifacts.require("./FABndesToken_GetDataToCall.sol");


module.exports = async (deployer, network, accounts) => {

	await deployer.deploy(RBBLib);
	await deployer.link(RBBLib, RBBRegistry);
	await deployer.link(RBBLib, FABndesToken);

	await deployer.deploy(RBBRegistry, accounts[0]);

	RBBRegistryInstance = await RBBRegistry.deployed();
	await RBBRegistryInstance.registryMock("123456789");

	await deployer.deploy(RBBToken, RBBRegistry.address, 2);
	await deployer.deploy(FABndesToken_BNDESRoles, RBBRegistry.address);
	await deployer.deploy(FABndesToken, RBBToken.address, FABndesToken_BNDESRoles.address, 3); 
	await deployer.deploy(FABndesToken_GetDataToCall, FABndesToken.address); 

	
};

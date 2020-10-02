var RBBLib = artifacts.require("./RBBLib.sol");
//var RBBRegistry = artifacts.require("./RBBRegistry.sol");
var SpecificRBBTokenRegistry = artifacts.require("./SpecificRBBTokenRegistry.sol");
var RBBToken = artifacts.require("./RBBToken.sol");
var FABndesToken = artifacts.require("./FABndesToken.sol");
var FABndesToken_BNDESRoles = artifacts.require("./FABndesToken_BNDESRoles.sol");
var FABndesToken_GetDataToCall = artifacts.require("./FABndesToken_GetDataToCall.sol");


module.exports = async (deployer, network, accounts) => {

	await deployer.deploy(RBBLib);
//	await deployer.link(RBBLib, RBBRegistry);
	await deployer.link(RBBLib, FABndesToken);

//linhas usadas para teste
//	await deployer.deploy(RBBRegistry, accounts[0]);
//	RBBRegistryInstance = await RBBRegistry.deployed();
//	await RBBRegistryInstance.registryMock("123456789");

//linhas usadas para deployar o novo registry
//	let CNPJ = 33657248000189;
//	let hash = "9c46ae9957f4589d4a4c50ff4eaf01a2516f755e20102ab59403c484e086f647"; //TODO: change the 9c46ae9957f4589d4a4c50ff4eaf01a2516f755e20102ab59403c484e086f647 to the hash of BNDES auto-declaration of address property and liability
//	await deployer.deploy(RBBRegistry, CNPJ, hash);	
//	var registryAddr = RBBRegistry.address;

//usado no deploy da RBB porque o BNDESRegistry jah foi deployado
	var registryAddr = "0x5BC83F7EeB7A46FB0a5d2B3e0215FAdB2A61Da53";

	await deployer.deploy(SpecificRBBTokenRegistry, registryAddr);
	await deployer.deploy(RBBToken, registryAddr, SpecificRBBTokenRegistry.address, 2);
	await deployer.deploy(FABndesToken_BNDESRoles, registryAddr);
	await deployer.deploy(FABndesToken, RBBToken.address, FABndesToken_BNDESRoles.address); 
	await deployer.deploy(FABndesToken_GetDataToCall, FABndesToken.address); 

	
};

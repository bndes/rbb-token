var RBBLib = artifacts.require("./RBBLib.sol");
//var RBBRegistry = artifacts.require("./RBBRegistry.sol");
var SpecificRBBTokenRegistry = artifacts.require("./SpecificRBBTokenRegistry.sol");
var RBBToken = artifacts.require("./RBBToken.sol");
var ESGBndesToken = artifacts.require("./ESGBndesToken.sol");
var ESGBndesToken_BNDESRoles = artifacts.require("./ESGBndesToken_BNDESRoles.sol");
var ESGBndesToken_GetDataToCall = artifacts.require("./ESGBndesToken_GetDataToCall.sol");


module.exports = async (deployer, network, accounts) => {

	await deployer.deploy(RBBLib);
//	await deployer.link(RBBLib, RBBRegistry);
	await deployer.link(RBBLib, ESGBndesToken);

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
	var registryAddr = "0x3C4fF27302eb323bd95B8181c9fC51F832A0ac13";

	let specificRBBTokenRegistryInstance = await deployer.deploy(SpecificRBBTokenRegistry, registryAddr);
	await deployer.deploy(RBBToken, registryAddr, SpecificRBBTokenRegistry.address, 2);
	await deployer.deploy(ESGBndesToken_BNDESRoles, registryAddr);
	await deployer.deploy(ESGBndesToken, RBBToken.address, ESGBndesToken_BNDESRoles.address); 
	await deployer.deploy(ESGBndesToken_GetDataToCall, ESGBndesToken.address); 

//	usar conta 1 registrar contrato especifico (endereço de EsgBndesToken). Chamar o método registerSpecificRBBToken do contrato SpecificRBBTokenRegistry.sol.
	specificRBBTokenRegistryInstance.registerSpecificRBBToken(ESGBndesToken.address);
	
};

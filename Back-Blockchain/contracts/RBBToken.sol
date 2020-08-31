pragma solidity ^0.5.0;

import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./SpecificRBBToken.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

    
contract BusinessContractRegistry is Ownable {

    //It starts with 1, because 0 is the id value returned when the item is not found in the businessContractsRegistry
    uint public idCount = 1;

    struct BusinessContractInfo {
        uint id;
        bool isActive;
        uint totalSupply;
        //totalInUse?
    }

    event BusinessContractRegistration (uint id, address addr);
    event BusinessContractStateChange (uint id, bool state);

    //indexado pelo address pq serah a forma mais usada para consulta.
    mapping (address => BusinessContractInfo) public businessContractsRegistry;

    modifier onlyByRegisteredAndActiveContracts {
        require(containsBusinessContract(msg.sender), "Método só pode ser chamado por contrato de negócio previamente cadastrado");
        require(isBusinessContractActive(msg.sender), "Método só pode ser chamado por contrato de negócio ativo");
        _;
    }


    function getBusinessContractId (address addr) public view returns (uint) {
        require (containsBusinessContract(addr), "Contrato de negocio nao registrado");
        BusinessContractInfo memory info = businessContractsRegistry[addr];
        return info.id;
    }
    
    function containsBusinessContract(address addr) public view returns (bool) {
        BusinessContractInfo memory info = businessContractsRegistry[addr];
        if (info.id!=0) return true;
        else return false;
    }

    function isBusinessContractActive(address addr) public view returns (bool) {
        require (containsBusinessContract(addr), "Contrato de negocio nao registrado");
        BusinessContractInfo memory info = businessContractsRegistry[addr];
        return info.isActive;
    }

    function setStatus(address addr, bool status) public onlyOwner returns (bool) {
        require (containsBusinessContract(addr), "Contrato de negocio nao registrado");
        BusinessContractInfo storage info = businessContractsRegistry[addr];
        info.isActive = status;
        emit BusinessContractStateChange(info.id, info.isActive);
    }

    function getBusinessContractHash(address addr) public returns (bytes32) {
        uint contractId = getBusinessContractId(addr);
        return keccak256(abi.encodePacked(contractId));
    }

}

//TODO: pensar - se precisasse fazer upgrade de um contrato, seria somente registrar um contrato com id do anterior. Criar um metodo para facilitar isso para facilitar o código de mudanças?
contract RBBToken is Pausable, BusinessContractRegistry {

    using SafeMath for uint;

    RBBRegistry public registry;

    uint8 public decimals = 2;
//    uint8 public RESERVED_ID_VALUE = 0;
//    bytes32 public RESERVED_HASH_VALUE = 0x0000000000000000000000000000000000000000000000000000000000000000;


    event RBBMintRequest(uint businessContractId, uint amount);
    event RBBTokenMint(uint businessContractId, uint amount);
    event RBBTokenBurn(uint businessContractId, uint amount);
    event RBBTokenTransfer (uint businessContractId, uint fromId, bytes32 fromHash, uint toId,
                            bytes32 toHash, uint amount);


    constructor (address newRegistryAddr, uint8 _decimals) public {
        registry = RBBRegistry(newRegistryAddr);
        decimals = _decimals;
    }

    function registerBusinessContract (address addr) public onlyOwner returns (uint)  {
        require (!containsBusinessContract(addr), "Contrato já registrado");

        //Verifies that this address belongs to a proper class
        //USAR 165?
        SpecificRBBToken spt = SpecificRBBToken(addr);
        //ver qual o numero???????????/
//        require (spt.transfer.selector==23, "transfer function is not the expected one");
        spt.register( address(registry) );

        //Register the new class
        businessContractsRegistry[addr] = BusinessContractInfo(idCount, true, 0);
        emit BusinessContractRegistration (idCount, addr);
        idCount++;
    }
///******************************************************************* */

    function requestMint(uint amount) public whenNotPaused onlyByRegisteredAndActiveContracts {
    
        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        address businessContractAddr = msg.sender;
        uint businessContractId = getBusinessContractId(businessContractAddr);
    
    //precisa guardar em uma estrutuda de dados?
        emit RBBMintRequest(businessContractId, amount);

    }

    function mint(address businessContractAddr, uint amount) whenNotPaused public onlyOwner {
        require(isBusinessContractActive(businessContractAddr), "Contrato precisa estar ativo para haver emissão");
        require(amount>0, "Valor a emitir deve ser maior do que zero");
        BusinessContractInfo storage info = businessContractsRegistry[businessContractAddr];        
        info.totalSupply = info.totalSupply.add(amount);        
        emit RBBTokenMint(info.id, amount);

        //Incluir valor emitido na conta bndes
        SpecificRBBToken st = SpecificRBBToken(businessContractAddr);
        uint idOwberRBBToken = registry.getId(owner()); 
        st.allocate(idOwberRBBToken, amount);

    }

    function burn (address businessContractAddr, uint amount) whenNotPaused public onlyOwner {
        _burn(businessContractAddr, amount);
    }

    function burnBySpecificContract(uint amount) public whenNotPaused onlyByRegisteredAndActiveContracts {
        address businessContractAddr = msg.sender;
        _burn(businessContractAddr, amount);
    }

    function _burn(address businessContractAddr, uint amount) internal {
        require(isBusinessContractActive(businessContractAddr), "Contrato precisa estar ativo para haver burn");
        require(amount>0, "Valor a queimar deve ser maior do que zero");
        BusinessContractInfo storage info = businessContractsRegistry[businessContractAddr];        
        info.totalSupply = info.totalSupply.sub(amount, "Burn amount exceeds balance");        
        emit RBBTokenBurn(info.id, amount);
    }

    function registerTransfer (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, uint amount)
        public whenNotPaused onlyByRegisteredAndActiveContracts {
        uint businessContractId = getBusinessContractId(msg.sender);
        emit RBBTokenTransfer (businessContractId, fromId, fromHash, toId, toHash, amount);    
    }

/*    
    function getReservedBalanceByBusinessContract(address businessContractAddr) view public returns (uint) {
        uint businessContractId = getBusinessContractId(businessContractAddr);
        return rbbBalances[businessContractId][RESERVED_ID_VALUE][RESERVED_HASH_VALUE];
    }
*/
    function getDecimals() public view returns (uint8) {
        return decimals;
    }

}
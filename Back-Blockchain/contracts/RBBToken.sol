pragma solidity ^0.5.0;

import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract BusinessContractRegistry is Ownable {

    //It starts with 1, because 0 is the id value returned when the item is not found in the businessContractsRegistry
    uint public idCount = 1;

    struct BusinessContractInfo {
        uint id;
        bool isActive;
    }

    event BusinessContractRegistration (uint id, address addr);
    event BusinessContractStateChange (uint id, bool state);

    //indexado pelo address pq serah a forma mais usada para consulta.
    mapping (address => BusinessContractInfo) public businessContractsRegistry;

    modifier onlyByRegisteredAndActiveContracts {
        require(containsBusinessContract(msg.sender), "Método só pode ser chamado por endereço de contrato de negócio previamente cadastrado");
        require(isBusinessContractActive(msg.sender), "Método só pode ser chamado por endereço de contrato de negócio ativo");
        _;
    }

    function registerBusinessContract (address addr) public onlyOwner returns (uint)  {
        require (!containsBusinessContract(addr), "Contrato já registrado");
        businessContractsRegistry[addr] = BusinessContractInfo(idCount, true);
        emit BusinessContractRegistration (idCount, addr);
        idCount++;
        //TODO: discutir se contrato deveria jah ser registrado como ativo (como feito acima)
    }

    function getBusinessContractId (address addr) public returns (uint) {
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

    function setStatus(address addr, bool status) public returns (bool) {
        require (containsBusinessContract(addr), "Contrato de negocio nao registrado");
        BusinessContractInfo storage info = businessContractsRegistry[addr];
        info.isActive = status;
        emit BusinessContractStateChange(info.id, info.isActive);
    }
}

//TODO: pensar - se precisasse fazer upgrade de um contrato, seria somente registrar um contrato com id do anterior. Criar um metodo para facilitar isso para facilitar o código de mudanças?

contract RBBToken is Pausable, BusinessContractRegistry {

    using SafeMath for uint;

    RBBRegistry public registry;

    uint8 public decimals = 2;
    uint8 public RESERVED_ID_VALUE = 0;
    bytes32 public RESERVED_HASH_VALUE = "0x0";

    //businessContractId => (RBBid => (specificHash => amount)
    mapping (uint => mapping (uint => mapping (bytes32 => uint))) public rbbBalances;

    event RBBTokenTransfer (uint businessContractId, uint fromId, bytes32 fromHash, uint toId,
                            bytes32 toHash, uint amount);
    event RBBTokenMint(uint businessContractId, uint amount);
    event RBBTokenBurn(uint businessContractId, uint amount);


    constructor (address newRegistryAddr, uint8 _decimals) public {
        registry = RBBRegistry(newRegistryAddr);
        decimals = _decimals;
    }


//TODO: avaliar se deve incluir um objeto genérico para registrar informacoes (ou deixa apenas nos contratos especificos)
    function transfer (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, uint amount) 
                        public whenNotPaused onlyByRegisteredAndActiveContracts {
        
        address businessContractAddr = msg.sender;
        uint businessContractId = getBusinessContractId(businessContractAddr);

        if (fromId!=RESERVED_ID_VALUE) {
            require(registry.isValidatedId(fromId), "Conta de origem precisa estar com cadastro validado");
        }
        if (toId!=RESERVED_ID_VALUE) {
            require(registry.isValidatedId(toId), "Conta de destino precisa estar com cadastro validado");
        }

        //altera valores de saldo
        rbbBalances[businessContractId][fromId][fromHash] =
            rbbBalances[businessContractId][fromId][fromHash].sub(amount, "Saldo da origem não é suficiente para a transferência");
        rbbBalances[businessContractId][toId][toHash] = rbbBalances[businessContractId][toId][toHash].add(amount);

        emit RBBTokenTransfer (businessContractId, fromId, fromHash, toId, toHash, amount);
    }

    //whenNotPaused?
    function mint(address businessContractAddr, uint amount) public onlyOwner {

        require(isBusinessContractActive(businessContractAddr), "Contrato precisa estar ativo");
        uint businessContractId = getBusinessContractId(businessContractAddr);
        rbbBalances[businessContractId][RESERVED_ID_VALUE][RESERVED_HASH_VALUE] = 
            rbbBalances[businessContractId][RESERVED_ID_VALUE][RESERVED_HASH_VALUE].add(amount);
        emit RBBTokenMint(businessContractId, amount);
    }

    //whenNotPaused?
    function burn (address businessContractAddr, uint amount) public onlyOwner {
        
        require(isBusinessContractActive(businessContractAddr), "Contrato precisa estar ativo");
        uint businessContractId = getBusinessContractId(businessContractAddr);
        rbbBalances[businessContractId][RESERVED_ID_VALUE][RESERVED_HASH_VALUE] = 
            rbbBalances[businessContractId][RESERVED_ID_VALUE][RESERVED_HASH_VALUE].sub(amount, "Burn amount exceeds balance");
        emit RBBTokenBurn(businessContractId, amount);
    }

    function getDecimals() public view returns (uint8) {
        return decimals;
    }

}


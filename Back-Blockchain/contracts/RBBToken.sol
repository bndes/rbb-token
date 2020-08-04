pragma solidity ^0.5.0;

import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

//TODO: incluir modificadores para pausar contratos
contract RBBToken is BusinessContractRegistry, Ownable, Pausable {

    using SafeMath for uint;

    RBBRegistry public registry;

    uint8 public decimals = 2;
    uint8 public RESERVED_ID_VALUE = 0;
    uint8 public RESERVED_HASH_VALUE = 0;

    //businessContractId => (RBBid => (specificHash => amount)
    mapping (uint => mapping (uint => mapping (uint => uint))) public rbbBalance;

    event RBBTokenTransfer (uint businessContractId, uint fromId, string fromHash, uint toId, 
                            string toHash, uint amount);
    event RBBTokenMint(uint contractId, uint amount);
    event RBBTokenBurn(uint contractId, uint amount);


    constructor (address newRegistryAddr, uint8 _decimals) public {
        registry = RBBRegistry(newRegistryAddr);
        decimals = _decimals;
    }


//TODO: avaliar se deve incluir um objeto genérico para registrar informacoes (ou deixa apenas nos contratos especificos)
    function transfer (uint fromId, string fromHash, uint toId, string toHash, uint amount) public onlyByRegisteredAndActiveContracts {
        
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
        rbbBalances[businessContractId][toId][toHash] = rbbBalances[businessContractId][idTo][toHash].add(amount);

        emit RBBTokenTransfer (businessContractId, fromId, fromHash, toId, toHash, amount);
    }

    function mint(uint contractId, uint amount) public onlyOwner {

        require(registry.isBusinessContractActive(contractId), "Contrato precisa estar ativo");
        rbbBalances[businessContractId][RESERVED_ID_VALUE][RESERVED_HASH_VALUE] = 
            rbbBalances[businessContractId][RESERVED_ID_VALUE][RESERVED_HASH_VALUE].add(amount);
        emit RBBTokenMint(contractId, amount);
    }

    function burn (uint contractId, uint amount) public onlyOwner {
        
        require(registry.isBusinessContractActive(clientId), "Contrato precisa estar ativo");
        rbbBalances[businessContractId][RESERVED_ID_VALUE][RESERVED_HASH_VALUE] = 
            rbbBalances[businessContractId][RESERVED_ID_VALUE][RESERVED_HASH_VALUE].sub(amount, "Burn amount exceeds balance");
        emit RBBTokenBurn(contractId, amount);
    }

    function getDecimals() public view returns (uint8) {
        return decimals;
    }

}


contract BusinessContractRegistry {

    int idCount = 0;

    struct BusinessContractInfo {
        int id;
        bool isActive;
    }

    //indexado pelo address pq serah a forma mais usada para consulta.
    mapping (address => BusinessContractInfo) businessContractsRegistry;

    modifier onlyByRegisteredAndActiveContracts {
        require(containsBusinessContract(msg.sender), "Método só pode ser chamado por endereço de contrato de negócio previamente cadastrado");
        //TODO: falta verificar se estah ativo
        _
    }

    function registerBusinessContract (address addr) public onlyOwner returns (int) {
        require (containsBusinessContract(addr), "Contrato já registrado");
        businessContractsRegistry[addr] = new BusinessContractInfo(idCount, false);
        idCount++;
    }

    function getBusinessContractId(address addr) public returns (uint) {

    }

    function containsBusinessContract(address addr) public returns (bool) {
        BusinessContractInfo info = businessContractsRegistry[addr];
        ?
    }

    function isBusinessContractActive(uint id) public returns (bool) {
        ?
        //throw if contract is not registered
    }

    function setStatus(address addr, bool status) public returns (bool) {
        BusinessContractInfo info = businessContractsRegistry[addr];
        ?
    }


//TODO: pensar - se precisasse fazer upgrade de um contrato, seria somente registrar um contrato com id do anterior. Criar um metodo para facilitar isso para facilitar o código de mudanças?
//TODO: levantar eventos para essa parte

}
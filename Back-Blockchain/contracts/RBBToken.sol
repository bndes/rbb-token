pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

//todo: decidir usar id or addr para os contratos especificos
//TODO: framework de mudanca e gestao descentralizada de mints e burns
contract BusinessContractRegistry is Ownable {

    //It starts with 1, because 0 is the id value returned when the item is not found in the businessContractsRegistry
    uint public idCount = 1;

    struct BusinessContractInfo {
        uint id;
        uint ownerId;
        bool isActive;
    }

    event BusinessContractRegistration (uint id, uint ownerId, address addr);
    event BusinessContractStateChange (uint id, bool state);

    //indexado pelo address pq serah a forma mais usada para consulta.
    mapping (address => BusinessContractInfo) public businessContractsRegistry;

    modifier onlyByRegisteredAndActiveContracts {
        require(containsBusinessContract(msg.sender), "Método só pode ser chamado por contrato de negócio previamente cadastrado");
        require(isBusinessContractActive(msg.sender), "Método só pode ser chamado por contrato de negócio ativo");
        _;
    }

//TODO: adicionar como ponto positivo do contrato genérico no PPT. nao eh possivel mudar o uint do owner sem mudar o contrato
    function registerBusinessContract (address addr, uint ownerId) public onlyOwner returns (uint)  {
        require (!containsBusinessContract(addr), "Contrato já registrado");
        businessContractsRegistry[addr] = BusinessContractInfo(idCount, ownerId, true);
        emit BusinessContractRegistration (idCount, ownerId, addr);
        idCount++;
    }

    function getBusinessContractId (address addr) public view returns (uint) {
        require (containsBusinessContract(addr), "Contrato de negocio nao registrado");
        BusinessContractInfo memory info = businessContractsRegistry[addr];
        return info.id;
    }

    function getBusinessContractIdAndOwnerId (address addr) public view returns (uint, uint) {
        require (containsBusinessContract(addr), "Contrato de negocio nao registrado");
        BusinessContractInfo memory info = businessContractsRegistry[addr];
        return (info.id, info.ownerId);
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
}

//TODO: pensar - se precisasse fazer upgrade de um contrato, seria somente registrar um contrato com id do anterior. Criar um metodo para facilitar isso para facilitar o código de mudanças?
contract RBBToken is Pausable, BusinessContractRegistry {

    using SafeMath for uint;

    RBBRegistry public registry;

    uint8 public decimals = 2;
//    uint8 public RESERVED_ID_VALUE = 0;
    bytes32 public RESERVED_HASH_VALUE = 0x0000000000000000000000000000000000000000000000000000000000000000;

    //businessContractId => (RBBid => (specificHash => amount)
    mapping (uint => mapping (uint => mapping (bytes32 => uint))) public rbbBalances;

//todo: incluir parametro de data nos eventos de transfer e redeem
    event RBBMintRequest(uint businessContractId, uint amount);
    event RBBTokenMint(uint businessContractId, uint amount);
    event RBBTokenBurn(uint businessContractId, uint amount);
    event RBBRedemptionRequested (uint businessContractId, uint fromId, bytes32 fromHash, uint amount);

    event RBBTokenTransfer (uint businessContractId, uint fromId, bytes32 fromHash, uint toId,
                            bytes32 toHash, uint amount);


    constructor (address newRegistryAddr, uint8 _decimals) public {
        registry = RBBRegistry(newRegistryAddr);
        decimals = _decimals;
    }

///******************************************************************* */

    function requestMint(uint amount) public onlyByRegisteredAndActiveContracts {
    
        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        address businessContractAddr = msg.sender;
        uint businessContractId = getBusinessContractId(businessContractAddr);
    
    //TODO: precisa guardar em uma estrutuda de dados?
        emit RBBMintRequest(businessContractId, amount);

    }

    function mint(address businessContractAddr, uint amount) public onlyOwner {

        require(isBusinessContractActive(businessContractAddr), "Contrato precisa estar ativo");
        (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);
        rbbBalances[businessContractId][businessContractOwnerId][RESERVED_HASH_VALUE] = 
            rbbBalances[businessContractId][businessContractOwnerId][RESERVED_HASH_VALUE].add(amount);
        emit RBBTokenMint(businessContractId, amount);
    }

    function burn (address businessContractAddr, uint amount) public onlyOwner {

        (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);
//TODO: confirmar que não precisa ter cadastro validado para ter esse burn
        _burn(businessContractAddr, businessContractOwnerId, RESERVED_HASH_VALUE, amount);

    }

    function _burn(address businessContractAddr, uint fromId, bytes32 fromHash, uint amount) internal {
        
        require(isBusinessContractActive(businessContractAddr), "Contrato precisa estar ativo para haver burn");
        require(amount>0, "Valor a queimar deve ser maior do que zero");
        
        uint businessContractId = getBusinessContractId(businessContractAddr);

        rbbBalances[businessContractId][fromId][fromHash].sub(amount, "Burn amount exceeds balance");

        emit RBBTokenBurn(businessContractId, amount);
    }

///******************************************************************* */


//myContract.call(bytes4(sha3("myFunction(uint256,bytes32,string)")), 42, 0xabc, "hello")
//chamados de intervenção manual também seriam feitos pelo transfer, com verificação de intervencao manual

//TODO: avaliar se deve incluir um objeto genérico para registrar informacoes (ou deixa apenas nos contratos especificos)
    function transfer (address businessContractAddr, uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public whenNotPaused {

//https://ethereum.stackexchange.com/questions/8912/calling-other-contracts-function-dynamically
//businessContractId, selector, dados                             

        require(containsBusinessContract(businessContractAddr), "Contrato específico especificado não está registrado");
        require(isBusinessContractActive(businessContractAddr), "Contrato específico não está ativo");

        businessContractAddr.call(bytes4(sha3(data[0])), fromId, fromHash, toId, toHash, amount, data);

        uint businessContractId = getBusinessContractId(businessContractAddr);

//        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
 //       address businessContractAddr = msg.sender;
 //       uint businessContractId = getBusinessContractId(businessContractAddr);

        require(registry.isValidatedId(fromId), "Conta de origem precisa estar com cadastro validado");
        require(registry.isValidatedId(toId), "Conta de destino precisa estar com cadastro validado");

        //altera valores de saldo
        rbbBalances[businessContractId][fromId][fromHash] =
                rbbBalances[businessContractId][fromId][fromHash].sub(amount, "Saldo da origem não é suficiente para a transferência");
        rbbBalances[businessContractId][toId][toHash] = rbbBalances[businessContractId][toId][toHash].add(amount);

        emit RBBTokenTransfer (businessContractId, fromId, fromHash, toId, toHash, amount);
    }

    function allocate (address businessContractAddr, uint toId, bytes32 toHash, uint amount, string[] memory data) public 
        whenNotPaused {

            (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);

            require(registry.isValidatedId(businessContractOwnerId), "Conta do owner do contrato específico precisa estar com cadastro validado");
            transfer(businessContractId, businessContractOwnerId, RESERVED_HASH_VALUE, toId, toHash, amount, data);
    }

    function redeem (address businessContractAddr, uint fromId, bytes32 fromHash, uint amount, string[] memory data) public 
        whenNotPaused  {

            (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);

            require(registry.isValidatedId(businessContractOwnerId), "Conta do owner do contrato específico precisa estar com cadastro validado");

            //?? Burn deveria ser de qq conta ou somente da conta reserva? conta reserva do BNDES? refletir no allocate?
            //transfer(businessContractId, fromId, fromHash, RESERVED_ID_VALUE, RESERVED_HASH_VALUE, amount);
            emit RBBRedemptionRequested(businessContractId, fromId, fromHash, amount);
            _burn(businessContractAddr, fromId, fromHash, amount);
    }

///******************************************************************* */


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
pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./SpecificRBBToken.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

//TODO: framework de mudanca e gestao descentralizada de mints e burns
contract BusinessContractRegistry is Ownable {

    RBBRegistry public registry;

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
    function registerBusinessContract (address businessContractAddr, uint ownerId) public onlyOwner returns (uint)  {
        require (!containsBusinessContract(businessContractAddr), "Contrato já registrado");

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        specificContract.setInitializationDataDuringRegistration(address(registry), address(this));


        businessContractsRegistry[businessContractAddr] = BusinessContractInfo(idCount, ownerId, true);
        emit BusinessContractRegistration (idCount, ownerId, businessContractAddr);
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

    uint8 public decimals = 2;
    bytes32 public RESERVED_HASH_VALUE = 0x0000000000000000000000000000000000000000000000000000000000000000;

    //businessContractId => (RBBid => (specificHash => amount)
    mapping (uint => mapping (uint => mapping (bytes32 => uint))) public rbbBalances;

    //businessContractId => (specificHash => amount)
    mapping (uint => mapping (bytes32 => uint)) public balanceTokensToMint;

//TODO: incluir parametro de data nos eventos de transfer e redeem? -- AVALIAR
    event RBBMintRequest(address businessContractAddr, uint amount);
    event RBBTokenMint(address businessContractAddr, uint amount);
    event RBBTokenBurn(address businessContractAddr, uint amount);
    event RBBRedemptionRequested (address businessContractAddr, uint fromId, bytes32 fromHash, uint amount);

    event RBBTokenTransfer (address businessContractAddr, uint fromId, bytes32 fromHash, uint toId,
                            bytes32 toHash, uint amount);
    event RBBRedemptionSettlement(address businessContractAddr, string redemptionTransactionHash, string receiptHash);


    constructor (address newRegistryAddr, uint8 _decimals) public {
        registry = RBBRegistry(newRegistryAddr);
        decimals = _decimals;
    }

//TODO: AVALIAR como identifica BNDES
    function getBndesId() view public returns (uint) {
        uint bndesId = registry.getId(owner());
        return bndesId;
    }

///******************************************************************* */

    function requestMint(uint amount, bytes32 specificHash) public onlyByRegisteredAndActiveContracts {
    
        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        address businessContractAddr = msg.sender;

        (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);

        balanceTokensToMint[businessContractId][specificHash] = 
            balanceTokensToMint[businessContractId][specificHash].add(amount);
    
        emit RBBMintRequest(businessContractAddr, amount);

    }

    function mint(address businessContractAddr, bytes32 specificHash, uint amount, string[] memory data, 
        string memory docHash) public onlyOwner {

        require(isBusinessContractActive(businessContractAddr), "Contrato precisa estar ativo");
        require (RBBLib.isValidHash(docHash), "O hash da comprovação é inválido");

        (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);

        balanceTokensToMint[businessContractId][specificHash] 
            = balanceTokensToMint[businessContractId][specificHash].sub(amount, "Total de emissão excede valor solicitado");

        rbbBalances[businessContractId][businessContractOwnerId][RESERVED_HASH_VALUE] = 
            rbbBalances[businessContractId][businessContractOwnerId][RESERVED_HASH_VALUE].add(amount);

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        specificContract.verifyAndActForMint(specificHash, amount, data, docHash);

        emit RBBTokenMint(businessContractAddr, amount);
    }

    function burn (address businessContractAddr, uint amount) public onlyOwner {

        (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);
//TODO: confirmar que contrato não precisa ter cadastro ativo para ter esse burn
        _burn(businessContractAddr, businessContractOwnerId, RESERVED_HASH_VALUE, amount);

    }

    function _burn(address businessContractAddr, uint fromId, bytes32 fromHash, uint amount) internal {
        
        require(isBusinessContractActive(businessContractAddr), "Contrato precisa estar ativo para haver burn");
        require(amount>0, "Valor a queimar deve ser maior do que zero");
        
        uint businessContractId = getBusinessContractId(businessContractAddr);

        rbbBalances[businessContractId][fromId][fromHash].sub(amount, "Total de tokens a serem queimados é maior do que o balance");

        emit RBBTokenBurn(businessContractAddr, amount);
    }

///******************************************************************* */


//chamados de intervenção manual também seriam feitos pelo transfer, com verificação de intervencao manual

//TODO: incluir hash de registro um objeto genérico para registrar informacoes
    function transfer (address businessContractAddr, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public whenNotPaused {

        uint fromId = registry.getId(msg.sender);

//TODO: ver se essas duas linhas seguintes devem estar em outros metodos
        require(containsBusinessContract(businessContractAddr), "Contrato específico especificado não está registrado");
        require(isBusinessContractActive(businessContractAddr), "Contrato específico não está ativo");

        require(registry.isValidatedId(fromId), "Conta de origem precisa estar com cadastro validado");
        require(registry.isValidatedId(toId), "Conta de destino precisa estar com cadastro validado");
        uint businessContractId = getBusinessContractId(businessContractAddr);

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        specificContract.verifyAndActForTransfer(fromId, fromHash, toId, toHash, amount, data);

        //altera valores de saldo
        rbbBalances[businessContractId][fromId][fromHash] =
                rbbBalances[businessContractId][fromId][fromHash].sub(amount, "Saldo da origem não é suficiente para a transferência");
        rbbBalances[businessContractId][toId][toHash] = rbbBalances[businessContractId][toId][toHash].add(amount);

        emit RBBTokenTransfer (businessContractAddr, fromId, fromHash, toId, toHash, amount);

    }

    function allocate (address businessContractAddr, uint toId, bytes32 toHash, uint amount, string[] memory data) public 
        whenNotPaused {


            (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);
            uint fromId = registry.getId(msg.sender);
            require (fromId==businessContractOwnerId, "Somente o Owner do contrato específico pode chamar esse método");

            transfer(businessContractAddr, RESERVED_HASH_VALUE, toId, toHash, amount, data);
    }

    function redeem (address businessContractAddr, uint fromId, bytes32 fromHash, uint amount, string[] memory data) public 
        whenNotPaused  {

            (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);

            require(registry.isValidatedId(fromId), "Conta solicitante do redeem precisa estar com cadastro validado");

            SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
            specificContract.verifyAndActForRedeem(fromId, fromHash, amount, data);

            emit RBBRedemptionRequested(businessContractAddr, fromId, fromHash, amount);
            _burn(businessContractAddr, fromId, fromHash, amount);
    }

   /**
    * Using this function, the Responsible for Settlement indicates that he has made the FIAT money transfer.
    * @ param redemptionTransactionHash hash of the redeem transaction in which the FIAT money settlement occurred.
    * @ param receiptHash hash that proof the FIAT money transfer
    */ 
    function notifyRedemptionSettlement(address businessContractAddr, string memory redemptionTransactionHash, 
        string memory receiptHash, string[] memory data)
        public whenNotPaused onlyOwner {

        require (RBBLib.isValidHash(receiptHash), "O hash da comprovação é inválido");

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        specificContract.verifyAndActForRedemptionSettlement(redemptionTransactionHash, receiptHash, data);

        emit RBBRedemptionSettlement(businessContractAddr, redemptionTransactionHash, receiptHash);
    }
    

///******************************************************************* */

    function getReservedBalanceByBusinessContract(address businessContractAddr) view public returns (uint) {

        (uint businessContractId, uint businessContractOwnerId) = 
                getBusinessContractIdAndOwnerId(businessContractAddr);
        return rbbBalances[businessContractId][businessContractOwnerId][RESERVED_HASH_VALUE];
    }

    function getDecimals() public view returns (uint8) {
        return decimals;
    }

}
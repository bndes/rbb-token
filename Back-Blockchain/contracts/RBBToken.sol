pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./SpecificRBBToken.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

//TODO: framework de mudanca e como incluir um business contract com um id específico
//TODO: avaliar se precisa ter totalSupply de cada contrato ou outras info derivadas para aumentar programabilidade
contract BusinessContractRegistry is Ownable {

    RBBRegistry public registry;

    //It starts with 1, because 0 is the id value returned when the item is not found in the businessContractsRegistry
    uint public idCount = 1;

    struct BusinessContractInfo {
        uint id;
        bool isActive;
    }

    event BusinessContractRegistration (uint id, uint ownerId, address addr);
    event BusinessContractStateChange (uint id, bool state);

    //indexado pelo address pq serah a forma mais usada para consulta.
    mapping (address => BusinessContractInfo) public businessContractsRegistry;

    modifier onlyByRegisteredAndActiveContracts {
        verifyContractIsRegisteredAndActive(msg.sender);
        _;
    }

    function verifyContractIsRegisteredAndActive(address addr) public {
        require(containsBusinessContract(addr), "Método só pode ser chamado por contrato de negócio previamente cadastrado");
        require(isBusinessContractActive(addr), "Método só pode ser chamado por contrato de negócio ativo");
    }

    function registerBusinessContract (address businessContractAddr) public onlyOwner returns (uint)  {
        require (!containsBusinessContract(businessContractAddr), "Contrato já registrado");

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        specificContract.setInitializationDataDuringRegistration(address(registry), address(this));
        address scOwnerAddr = specificContract.owner();
        uint scOwnerId = registry.getId(scOwnerAddr);


        businessContractsRegistry[businessContractAddr] = BusinessContractInfo(idCount, true);
        emit BusinessContractRegistration (idCount, scOwnerId, businessContractAddr);
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
        SpecificRBBToken specificContract = SpecificRBBToken(addr);
        address scOwnerAddr = specificContract.owner();
        uint scOwnerId = registry.getId(scOwnerAddr);

        return (info.id, scOwnerId);
    }
    
    function containsBusinessContract(address addr) private view returns (bool) {
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

contract RBBToken is Pausable, BusinessContractRegistry {

    using SafeMath for uint;

    uint8 public decimals = 2;

    //businessContractId => (RBBid => (specificHash => amount)
    mapping (uint => mapping (uint => mapping (bytes32 => uint))) public rbbBalances;

    //businessContractId => (specificHash => amount)
    mapping (uint => mapping (bytes32 => uint)) public balaceRequestedTokens;

    event RBBTokenMintRequest(address businessContractAddr, bytes32 specificHash, uint idInvestor, uint amount);
    event RBBTokenMint(address businessContractAddr, bytes32 specificHash, uint amount, string docHash, string[] data);
    event RBBTokenBurn(address businessContractAddr, uint fromId, bytes32 fromHash, uint amount);
    event RBBTokenTransfer (address businessContractAddr, uint fromId, bytes32 fromHash, uint toId,
                            bytes32 toHash, uint amount, string[] data);
    event RBBTokenRedemptionRequested (address businessContractAddr, uint fromId, bytes32 fromHash, 
                            uint amount, string[] data);
    event RBBTokenRedemptionSettlement(address businessContractAddr, string redemptionTransactionHash, 
                            string receiptHash, string[] data);


    constructor (address newRegistryAddr, uint8 _decimals) public {
        registry = RBBRegistry(newRegistryAddr);
        decimals = _decimals;
    }



///******************************************************************* */

//TODO: incluir novo hash aqui?
    function requestMint(bytes32 specificHash, uint idInvestor, uint amount) public onlyByRegisteredAndActiveContracts {
    
        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        address businessContractAddr = msg.sender;

        verifyContractIsRegisteredAndActive(businessContractAddr);
        
        uint businessContractId = getBusinessContractId(businessContractAddr);

        balaceRequestedTokens[businessContractId][specificHash] = 
            balaceRequestedTokens[businessContractId][specificHash].add(amount);
    
        emit RBBTokenMintRequest(businessContractAddr, specificHash, idInvestor, amount);

    }

    function mint(address businessContractAddr, bytes32 specificHash, uint amount, string memory docHash,
        string[] memory data) public onlyOwner {

        verifyContractIsRegisteredAndActive(businessContractAddr);
        require(amount>0, "Valor a mintar deve ser maior do que zero");

        require (RBBLib.isValidHash(docHash), "O hash da comprovação é inválido");

        (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);

        balaceRequestedTokens[businessContractId][specificHash] 
            = balaceRequestedTokens[businessContractId][specificHash].sub(amount, "Total de emissão excede valor solicitado");

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        bytes32 calcHash = specificContract.getHashToMintedAccount(specificHash);

        rbbBalances[businessContractId][businessContractOwnerId][calcHash] = 
            rbbBalances[businessContractId][businessContractOwnerId][calcHash].add(amount);

        specificContract.verifyAndActForMint(specificHash, amount, data, docHash);

        emit RBBTokenMint(businessContractAddr, specificHash, amount, docHash, data);
    }

    function burnOwnTokenBySpecificContracts (bytes32 hashToBurn, uint amount) public onlyByRegisteredAndActiveContracts {

        address businessContractAddr = msg.sender;
        (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);
        
        _burn(businessContractAddr, businessContractOwnerId, hashToBurn, amount);

    }


    function burnOwnToken (address businessContractAddr, bytes32 hashToBurn, uint amount) public onlyByRegisteredAndActiveContracts {

        verifyContractIsRegisteredAndActive(businessContractAddr);

        uint idToBurn = registry.getId(msg.sender);

        _burn(businessContractAddr, idToBurn, hashToBurn, amount);

    }

    function _burn(address businessContractAddr, uint fromId, bytes32 fromHash, uint amount) internal {
        
        verifyContractIsRegisteredAndActive(businessContractAddr);
//        require(amount>0, "Valor a queimar deve ser maior do que zero");

        uint businessContractId = getBusinessContractId(businessContractAddr);

        rbbBalances[businessContractId][fromId][fromHash].sub(amount, "Total de tokens a serem queimados é maior do que o balance");

        emit RBBTokenBurn(businessContractAddr, fromId, fromHash, amount);
    }

///******************************************************************* */


//TODO: incluir hash de registro um objeto genérico para registrar informacoes
    function transfer (address businessContractAddr, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public whenNotPaused {

        uint fromId = registry.getId(msg.sender);

        verifyContractIsRegisteredAndActive(businessContractAddr);

        require(registry.isValidatedId(fromId), "Conta de origem precisa estar com cadastro validado");
        require(registry.isValidatedId(toId), "Conta de destino precisa estar com cadastro validado");
        uint businessContractId = getBusinessContractId(businessContractAddr);

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        specificContract.verifyAndActForTransfer(fromId, fromHash, toId, toHash, amount, data);

        //altera valores de saldo
        rbbBalances[businessContractId][fromId][fromHash] =
                rbbBalances[businessContractId][fromId][fromHash].sub(amount, "Saldo da origem não é suficiente para a transferência");
        rbbBalances[businessContractId][toId][toHash] = rbbBalances[businessContractId][toId][toHash].add(amount);

        emit RBBTokenTransfer (businessContractAddr, fromId, fromHash, toId, toHash, amount, data);

    }

    function redeem (address businessContractAddr, uint fromId, bytes32 fromHash, uint amount, string[] memory data) public 
        whenNotPaused  {

            verifyContractIsRegisteredAndActive(businessContractAddr);
            require(registry.isValidatedId(fromId), "Conta solicitante do redeem precisa estar com cadastro validado");
            require(amount>0, "Valor a resgatar deve ser maior do que zero");
    
            SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
            specificContract.verifyAndActForRedeem(fromId, fromHash, amount, data);

            emit RBBTokenRedemptionRequested(businessContractAddr, fromId, fromHash, amount, data);
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

        verifyContractIsRegisteredAndActive(businessContractAddr);
        require (RBBLib.isValidHash(receiptHash), "O hash da comprovação é inválido");

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        specificContract.verifyAndActForRedemptionSettlement(redemptionTransactionHash, receiptHash, data);

        emit RBBTokenRedemptionSettlement(businessContractAddr, redemptionTransactionHash, receiptHash, data);
    }
    

///******************************************************************* */

    function getDecimals() public view returns (uint8) {
        return decimals;
    }

    function getBndesId() view public returns (uint) {
        uint bndesId = registry.getId(owner());
        return bndesId;
    }

}
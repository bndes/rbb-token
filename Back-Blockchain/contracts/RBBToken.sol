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

    address public responsibleForInvestmentConfirmation;
    address public responsibleForSettlement;


    //businessContractId => (RBBid => (specificHash => amount)
    mapping (uint => mapping (uint => mapping (bytes32 => uint))) public rbbBalances;

    //businessContractId => (specificHash => amount)
    mapping (uint => mapping (bytes32 => uint)) public balaceRequestedTokens;

    event RBBTokenMintRequested(address businessContractAddr, bytes32 specificHash, uint idInvestor, 
            uint amount, bytes32 docHash);
    event RBBTokenMint(address businessContractAddr, bytes32 specificHash, uint amount, bytes32 docHash, string[] data);
    event RBBTokenBurn(address businessContractAddr, address originalSender, uint fromId, bytes32 fromHash, 
            uint amount, bytes32 docHash);
    event RBBTokenTransfer (address businessContractAddr, address originalSender, uint fromId, bytes32 fromHash, uint toId,
            bytes32 toHash, uint amount, bytes32 docHash, string[] data);
    event RBBTokenRedemptionRequested (address businessContractAddr, address originalSender, uint fromId, bytes32 fromHash, 
            uint amount, bytes32 docHash, string[] data);
    event RBBTokenRedemptionSettlement(address businessContractAddr, bytes32 redemptionTransactionHash, 
            bytes32 docHash, string[] data);

    event ManualIntervention_RoleOrAddress(address account, uint8 eventType);


    constructor (address newRegistryAddr, uint8 _decimals) public {
        registry = RBBRegistry(newRegistryAddr);
        decimals = _decimals;
        responsibleForInvestmentConfirmation = msg.sender;
        responsibleForSettlement = msg.sender;

    }

///******************************************************************* */

    function requestMint(bytes32 specificInvestimentHash, uint idInvestor, uint amount, bytes32 docHash) 
        public onlyByRegisteredAndActiveContracts {
    
        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        address businessContractAddr = msg.sender;

        verifyContractIsRegisteredAndActive(businessContractAddr);
        
        uint businessContractId = getBusinessContractId(businessContractAddr);

        balaceRequestedTokens[businessContractId][specificInvestimentHash] = 
            balaceRequestedTokens[businessContractId][specificInvestimentHash].add(amount);
    
        emit RBBTokenMintRequested(businessContractAddr, specificInvestimentHash, idInvestor, amount, docHash);

    }

    function mint(address businessContractAddr, bytes32 specificHash, uint amount, bytes32 docHash,
        string[] memory data) public {

        verifyContractIsRegisteredAndActive(businessContractAddr);

        require (responsibleForInvestmentConfirmation == msg.sender, 
            "Somente um responsável pela confirmação de investimento pode enviar a transação");

        require(amount>0, "Valor a mintar deve ser maior do que zero");

        (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);

        balaceRequestedTokens[businessContractId][specificHash] 
            = balaceRequestedTokens[businessContractId][specificHash].sub(amount, "Total de emissão excede valor solicitado");

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        bytes32 calcHash = specificContract.getHashToMintedAccount(specificHash);

        rbbBalances[businessContractId][businessContractOwnerId][calcHash] = 
            rbbBalances[businessContractId][businessContractOwnerId][calcHash].add(amount);

        specificContract.verifyAndActForMint(specificHash, amount, docHash, data);

        emit RBBTokenMint(businessContractAddr, specificHash, amount, docHash, data);
    }


    function burnOwnTokenBySpecificContracts (address originalSender, bytes32 hashToBurn, uint amount, 
        bytes32 docHash) public onlyByRegisteredAndActiveContracts {

        address businessContractAddr = msg.sender;
        (uint businessContractId, uint businessContractOwnerId) = 
                    getBusinessContractIdAndOwnerId(businessContractAddr);
        
        _burn(businessContractAddr, originalSender, businessContractOwnerId, hashToBurn, amount, docHash);

    }


    function burnOwnToken (address businessContractAddr, bytes32 hashToBurn, uint amount, bytes32 docHash) 
        public onlyByRegisteredAndActiveContracts {

        verifyContractIsRegisteredAndActive(businessContractAddr);

        uint idToBurn = registry.getId(msg.sender);

        _burn(businessContractAddr, msg.sender, idToBurn, hashToBurn, amount, docHash);

    }

    function _burn(address businessContractAddr, address originalSender, uint fromId, bytes32 fromHash, 
        uint amount, bytes32 docHash) internal {
        
        verifyContractIsRegisteredAndActive(businessContractAddr);
//        require(amount>0, "Valor a queimar deve ser maior do que zero");

        uint businessContractId = getBusinessContractId(businessContractAddr);

        rbbBalances[businessContractId][fromId][fromHash].sub(amount, "Total de tokens a serem queimados é maior do que o balance");

        emit RBBTokenBurn(businessContractAddr, originalSender, fromId, fromHash, amount, docHash);
    }

///******************************************************************* */


    function transfer (address businessContractAddr, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash, string[] memory data) public whenNotPaused {

        uint fromId = registry.getId(msg.sender);

        verifyContractIsRegisteredAndActive(businessContractAddr);

        require(registry.isValidatedId(fromId), "Conta de origem precisa estar com cadastro validado");
        require(registry.isValidatedId(toId), "Conta de destino precisa estar com cadastro validado");
        uint businessContractId = getBusinessContractId(businessContractAddr);

        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        specificContract.verifyAndActForTransfer(msg.sender, fromId, fromHash, toId, toHash, amount, docHash, data);

        //altera valores de saldo
        rbbBalances[businessContractId][fromId][fromHash] =
                rbbBalances[businessContractId][fromId][fromHash].sub(amount, "Saldo da origem não é suficiente para a transferência");
        rbbBalances[businessContractId][toId][toHash] = rbbBalances[businessContractId][toId][toHash].add(amount);

        emit RBBTokenTransfer (businessContractAddr, msg.sender, fromId, fromHash, toId, toHash, amount, docHash, data);

    }

    function redeem (address businessContractAddr, bytes32 fromHash, uint amount, 
        bytes32 docHash, string[] memory data) public whenNotPaused  {

            uint fromId = registry.getId(msg.sender);

            verifyContractIsRegisteredAndActive(businessContractAddr);
            require(registry.isValidatedId(fromId), "Conta solicitante do redeem precisa estar com cadastro validado");
            require(amount>0, "Valor a resgatar deve ser maior do que zero");
    
            SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
            specificContract.verifyAndActForRedeem(msg.sender, fromId, fromHash, amount, docHash, data);

            emit RBBTokenRedemptionRequested(businessContractAddr, msg.sender, fromId, fromHash, amount, docHash, data);
            _burn(businessContractAddr, msg.sender, fromId, fromHash, amount, docHash);
    }

   /**
    * Using this function, the Responsible for Settlement indicates that he has made the FIAT money transfer.
    * @ param redemptionTransactionHash hash of the redeem transaction in which the FIAT money settlement occurred.
    * @ param receiptHash hash that proof the FIAT money transfer
    */ 
    function notifyRedemptionSettlement(address businessContractAddr, bytes32 redemptionTransactionHash, 
        bytes32 docHash, string[] memory data) public whenNotPaused {

        verifyContractIsRegisteredAndActive(businessContractAddr);

        require (responsibleForSettlement == msg.sender, 
            "Somente um responsável pela liquidição pode enviar a transação");


        SpecificRBBToken specificContract = SpecificRBBToken(businessContractAddr);
        specificContract.verifyAndActForRedemptionSettlement(redemptionTransactionHash, docHash, data);

        emit RBBTokenRedemptionSettlement(businessContractAddr, redemptionTransactionHash, docHash, data);
    }
    

///******************************************************************* */

    function getDecimals() public view returns (uint8) {
        return decimals;
    }

    function getBndesId() view public returns (uint) {
        uint bndesId = registry.getId(owner());
        return bndesId;
    }

    function setResponsibleForInvestmentConfirmation(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pela confirmação do investimento deve ser do mesmo RBB_ID do contrato");
        responsibleForInvestmentConfirmation = rs;
        emit ManualIntervention_RoleOrAddress(rs, 1);
    }

    function setResponsibleForSettlement(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pela liquidação deve ser da mesmo RBB_ID do contrato");
        responsibleForSettlement = rs;
        emit ManualIntervention_RoleOrAddress(rs, 2);
    }


}
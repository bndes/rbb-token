pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./RBBLib.sol";

/*
Acho que LegalEntityInfo deveria conter id, ao invés de cnpj
No caso de pessoa jurídica, o id é o cnpj
No caso de pessoa física, um link para um cpf (por causa da LGPD).
*/
contract RBBRegistry is Ownable() {

    /**
        The account of clients and suppliers are assigned to states.
        AVAILABLE - The account is not yet assigned any role.
        WAITING_VALIDATION - The account was linked to a legal entity but it still needs to be validated
        VALIDATED - The account was validated
        INVALIDATED_BY_VALIDATOR - The account was invalidated
        INVALIDATED_BY_CHANGE - The client or supplier changed the ethereum account so the original one must be invalidated.
     */
    enum BlockchainAccountState {AVAILABLE,WAITING_VALIDATION,VALIDATED,INVALIDATED_BY_VALIDATOR,INVALIDATED_BY_CHANGE}
    BlockchainAccountState blockchainState; //Not used. Defined to create the enum type.

//TODO: deverá ser um conjunto de validadores, com possibilidade de incluir/remover novos,
//TODO: owner n pode ser BNDES
//Tratar como address ou como id?
    address responsibleForRegistryValidation;

    //todo: avaliar criacao de papel de invalidador para casos ad-hoc

    /**
        Describes the Legal Entity - clients or suppliers
     */
    struct LegalEntityInfo {
        uint id; //Brazilian identification of legal entity
        string idProofHash; //hash of declaration
        BlockchainAccountState state;
    }

    /**
        Links Ethereum addresses to LegalEntityInfo
     */
    mapping(address => LegalEntityInfo) public legalEntitiesInfo;

    /**
        Links Legal Entity to Ethereum address.
     */
    mapping(uint => address) legalEntityId_To_Addr;


    /**
        Links Ethereum addresses to the possibility to change the account
        Since the Ethereum account can be changed once, it is not necessary to put the bool to false.
        TODO: Discuss later what is the best solution to this
     */
    mapping(address => bool) public legalEntitiesChangeAccount;


    event AccountRegistration(address addr, uint id,  string idProofHash);
    event AccountChange(address oldAddr, address newAddr, uint id, string idProofHash);
    event AccountValidation(address addr, uint id);
    event AccountInvalidation(address addr, uint id);

    constructor (uint idResposibleForValidation) public {
        responsibleForRegistryValidation = msg.sender;
        legalEntitiesInfo[msg.sender] = LegalEntityInfo(idResposibleForValidation, "", BlockchainAccountState.VALIDATED);
        legalEntityId_To_Addr[idResposibleForValidation] = responsibleForRegistryValidation;
        emit AccountRegistration(msg.sender, idResposibleForValidation, "");
    }

   /**
    * Link blockchain address with ID - It can be a cliente or a supplier
    * The link still needs to be validated by BNDES
    * This method can only be called by BNDESToken contract because BNDESToken can pause.
    * @param cnpj Brazilian identifier to legal entities
    * @param idProofHash The legal entities have to send BNDES a PDF where it assumes as responsible for an Ethereum account.
    *                   This PDF is signed with eCNPJ and send to BNDES.
    */
    function registryLegalEntity(uint cnpj, string memory idProofHash)
        public {
        
        address addr = msg.sender;

        // Endereço não pode ter sido cadastrado anteriormente
        require (isAvailableAccount(addr), "Endereço não pode ter sido cadastrado anteriormente");

        require (RBBLib.isValidHash(idProofHash), "O hash da declaração é inválido");

//?? Avaliar se essa verificacao serah feita

        address account = getBlockchainAccount(cnpj);

        require (isAvailableAccount(account), "CNPJ Já está associado. Use a função Troca.");

        legalEntitiesInfo[addr] = LegalEntityInfo(cnpj, idProofHash, BlockchainAccountState.WAITING_VALIDATION);

        legalEntityId_To_Addr[cnpj] = addr;

        emit AccountRegistration(addr, cnpj, idProofHash);
    }





   /**
    * By default, the owner is also the Responsible for Validation.
    * The owner can assign other address to be the Responsible for Validation.
    * @param rs Ethereum address to be assigned as Responsible for Validation.
    */
    function setResponsibleForRegistryValidation(address rs) public onlyOwner {
        responsibleForRegistryValidation = rs;
        //TODOO: evento quando trocar papeis
    }




    function isResponsibleForRegistryValidation(address addr) public view returns (bool) {
        return (addr == responsibleForRegistryValidation);
    }

    function isOwner(address addr) public view returns (bool) {
        return owner()==addr;
    }

    function isAvailableAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.AVAILABLE;
    }

//TODO: eh necessario ter metodos que verificam se id ou address estao validos

    function isWaitingValidationAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.WAITING_VALIDATION;
    }

    function isValidatedAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.VALIDATED;
    }

    function isValidatedId(uint id) public view returns (bool) {
        address addr = getBlockchainAccount(id);
        return isValidatedAccount(addr);
    }

    function isInvalidatedByValidatorAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.INVALIDATED_BY_VALIDATOR;
    }

    function isInvalidatedByChangeAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.INVALIDATED_BY_CHANGE;
    }

    function getResponsibleForRegistryValidation() public view returns (address) {
        return responsibleForRegistryValidation;
    }

    function getId (address addr) public view returns (uint) {
        return legalEntitiesInfo[addr].id;
    }

    function getLegalEntityInfo (address addr) public view returns (uint, string memory, uint, address) {
        return (legalEntitiesInfo[addr].id, legalEntitiesInfo[addr].idProofHash, (uint) (legalEntitiesInfo[addr].state),
             addr);
    }

    function getBlockchainAccount(uint cnpj) public view returns (address) {
        return legalEntityId_To_Addr[cnpj];
    }

    function getLegalEntityInfoById (uint cnpj) public view
        returns (uint, string memory, uint, address) {
        
        address addr = getBlockchainAccount(cnpj);
        return getLegalEntityInfo (addr);
    }

    function getAccountState(address addr) public view returns (int) {
        return ((int) (legalEntitiesInfo[addr].state));
    }

    function registryMock(uint cnpj)
        public {
        
        address addr = msg.sender;
        string memory idProofHash = "";

        legalEntitiesInfo[addr] = LegalEntityInfo(cnpj, idProofHash, BlockchainAccountState.VALIDATED);

        legalEntityId_To_Addr[cnpj] = addr;

        emit AccountRegistration(addr, cnpj, idProofHash);
    }


}
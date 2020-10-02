pragma solidity ^0.6.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./RBBLib.sol";

contract RBBRegistry is Ownable() {

    enum BlockchainAccountState {AVAILABLE,WAITING_VALIDATION,VALIDATED,INVALIDATED}
    BlockchainAccountState blockchainState; /* Variable not used, only defined to create the enum type. */
                                
    /**
    REGULAR  - operates 
    ADMIN    - validates the regular.
    SUPADMIN - validates the ADMIN. Contract Owner can set multiple SUPADMINs (including himself, machines and human accounts).
     */
    enum BlockchainAccountRole {REGULAR, ADMIN, SUPADMIN} 
    BlockchainAccountRole blockchainRole;  /* Variable not used, only defined to create the enum type. */

    /* This is a helper variable to emulate a sequence and autoincrement Ids*/
    uint public currentRBBId = 0;

     /**
        This registry is about a company representative information
     */    
    struct Registry {
        uint RBBId; //Unique ID for RBB 
        uint CNPJ; //Brazilian identification of legal entity
        bytes32 hashProof; //hash of declaration
        BlockchainAccountState state;
        BlockchainAccountRole role;
        bool paused;
        uint256 dateTimeExpiration; //vai ser outro momento de expiração diferente do ECNPJ
    }

    uint256 public defaultDateTimeExpiration = 365 days; 

    /**
        Links Ethereum addresses to Registry
     */
    mapping(address => Registry) public legalEntitiesInfo;

    /**
        Links CNPJ to Ethereum addresses.
     */
    mapping(uint => address[]) legalEntityId_To_Addr;

    event AccountRegistration       (address addr, uint RBBId, uint CNPJ, bytes32 hashProof, uint256 dateTimeExpiration);
    event AccountValidation         (address addr, uint RBBId, uint CNPJ, address responsible);
    event AccountInvalidation       (address addr, uint RBBId, uint CNPJ, address responsible);
    event AccountPaused             (address addr, uint RBBId, uint CNPJ, address responsible);
    event AccountUnpaused           (address addr, uint RBBId, uint CNPJ, address responsible);
    event AccountRoleChange         (address addr, uint RBBId, uint CNPJ, address responsible, BlockchainAccountRole roleBefore, BlockchainAccountRole roleNew);
    event RegistryExpirationChange  (address addr, uint256 dateTimeExpirationBefore, uint256 dateTimeExpirationNew);

    /* The responsible for the System-Admin is the Owner. It could be or not be the same address (SUPADMIN=owner) */
    constructor (uint CNPJSUPADMIN, string memory proofHashSUPADMIN) public {                
        address addrSUPADMIN = msg.sender;
        bytes32 proofHash = RBBLib.stringBytes32(proofHashSUPADMIN);
        uint256 dateTimeExpiration = now + defaultDateTimeExpiration;
        uint RBBId = getNextRBBId();
        legalEntitiesInfo[addrSUPADMIN] = Registry( RBBId, 
                                                    CNPJSUPADMIN, 
                                                    proofHash, 
                                                    BlockchainAccountState.VALIDATED, 
                                                    BlockchainAccountRole.SUPADMIN, 
                                                    false, 
                                                    dateTimeExpiration     );
        legalEntityId_To_Addr[CNPJSUPADMIN].push(addrSUPADMIN);
        emit AccountRegistration(addrSUPADMIN, RBBId, CNPJSUPADMIN, proofHash, dateTimeExpiration); 
        
    }

   /**
    * Link blockchain address with CNPJ
    * @param CNPJ Brazilian identifier to legal entities
    * @param CNPJProofHash The legal entities have to send BNDES a PDF where it assumes as responsible for an Ethereum account.
    *                   This PDF is signed with eCNPJ and send to BNDES.
    */
    function registryLegalEntity(uint CNPJ, bytes32 CNPJProofHash) public {
        
        address addr = msg.sender;
        bytes32 proofHash = CNPJProofHash;
        uint256 dateTimeExpiration = now + defaultDateTimeExpiration;
        uint RBBId = getNextRBBId();

        require (isAvailableAccount(addr), "Endereço não pode ter sido cadastrado anteriormente");

        if ( proofHash == 0 ) { 
            legalEntitiesInfo[addr] = Registry( RBBId,
                                                CNPJ, 
                                                proofHash, 
                                                BlockchainAccountState.WAITING_VALIDATION, 
                                                BlockchainAccountRole.REGULAR,
                                                false,
                                                dateTimeExpiration );
        } else {
            legalEntitiesInfo[addr] = Registry( RBBId,
                                                CNPJ, 
                                                proofHash, 
                                                BlockchainAccountState.WAITING_VALIDATION, 
                                                BlockchainAccountRole.ADMIN,
                                                false,
                                                dateTimeExpiration );
        }

        legalEntityId_To_Addr[CNPJ].push(addr);

        emit AccountRegistration(addr, RBBId, CNPJ, proofHash, dateTimeExpiration);
    }

    modifier onlyWhenNotPaused() { 
        require( ! legalEntitiesInfo[msg.sender].paused , "Apenas quem não está pausada pode acessar" );
        _;
    }

    modifier onlyWhenNotExpired() { 
        require( legalEntitiesInfo[msg.sender].dateTimeExpiration > now , "Apenas contas com declarações cujos certificados ainda são válidos." );
        _;
    }

   /**
    * Validates the initial registry of your own LegalEntity
    * @param userAddr Ethereum address that needs to be validated
    */
    function validateRegistrySameOrg(address userAddr) public onlyWhenNotPaused onlyWhenNotExpired {

        address responsible = msg.sender;

        require ( responsible != userAddr, "O responsável pela validação não pode validar sua própria conta");

        require ( legalEntitiesInfo[responsible].role == BlockchainAccountRole.ADMIN , 
                   "O responsável pela validação deve ter o papel ADMIN" );

        require ( isTheSameID(responsible, userAddr) , 
                   "O responsável pela validação deve ser da mesma organização (mesmo CNPJ)" );

        require ( legalEntitiesInfo[userAddr].role == BlockchainAccountRole.REGULAR , 
                   "O usuário a ser validado deve ter o papel REGULAR" );


        require( legalEntitiesInfo[userAddr].state == BlockchainAccountState.WAITING_VALIDATION,
                   "A conta a validar precisa estar no estado Aguardando Validação");

        legalEntitiesInfo[userAddr].state = BlockchainAccountState.VALIDATED;

        emit AccountValidation( userAddr, 
                                legalEntitiesInfo[userAddr].RBBId, 
                                legalEntitiesInfo[userAddr].CNPJ, 
                                responsible);
    }

/**
    * Validates the initial registry of others LegalEntities
    * @param userAddr Ethereum address that needs to be validated
    */
    function validateRegistry(address userAddr) public onlyWhenNotExpired {

        address responsible = msg.sender;
        
        require ( legalEntitiesInfo[responsible].role == BlockchainAccountRole.SUPADMIN 
            , "O responsável pela validação deve ser SUPADMIN" );

        require ( legalEntitiesInfo[userAddr].role == BlockchainAccountRole.ADMIN  
            , "A conta a validar deve ter o papel de ADMIN" );

        require(legalEntitiesInfo[userAddr].state == BlockchainAccountState.WAITING_VALIDATION,
            "A conta precisa estar no estado Aguardando Validação");

        legalEntitiesInfo[userAddr].state = BlockchainAccountState.VALIDATED;

        emit AccountValidation( userAddr, 
                                legalEntitiesInfo[userAddr].RBBId, 
                                legalEntitiesInfo[userAddr].CNPJ, 
                                responsible);
    }    

/**
    * Pause an account     
    * @param addr Ethereum address that needs to be paused
    */
    function pauseAddress(address addr) public onlyWhenNotPaused {

        address responsible = msg.sender;

        require ( legalEntitiesInfo[addr].role != BlockchainAccountRole.SUPADMIN , "A conta SUPADMIN não pode ser pausada");
        require( isTheSameID(responsible, addr) || legalEntitiesInfo[responsible].role == BlockchainAccountRole.SUPADMIN, "Somente pode pausar uma conta quem for da mesma organização ou System Administrator" );
        require( isValidatedAccount(addr) , "Somente uma conta válida pode ser pausada");
        require( legalEntitiesInfo[responsible].state == BlockchainAccountState.VALIDATED, "O responsável deve possuir uma conta Válida" );

        legalEntitiesInfo[addr].paused = true;
        
        emit AccountPaused( addr, 
                            legalEntitiesInfo[addr].RBBId,
                            legalEntitiesInfo[addr].CNPJ, 
                            responsible);
    }

    function pauseLegalEntity(uint CNPJ) public onlyWhenNotPaused {

        address responsible = msg.sender;
        address[] memory addresses  = legalEntityId_To_Addr[CNPJ];

        require( legalEntitiesInfo[responsible].state == BlockchainAccountState.VALIDATED, "O responsável deve possuir uma conta Válida" );
        require( ( legalEntitiesInfo[responsible].role == BlockchainAccountRole.ADMIN 
                    || legalEntitiesInfo[responsible].role == BlockchainAccountRole.SUPADMIN ), "O responsável deve possuir uma conta ADMIN ou SUPADMIN" );
        require( isTheSameID(responsible, addresses[0]) 
                    || legalEntitiesInfo[responsible].role == BlockchainAccountRole.SUPADMIN , "Somente pode pausar uma conta quem for da mesma organização ou SUPADMIN" );

        for (uint i=0; i < addresses.length ; i++) {
            address candidate = addresses[i];
            if( isValidatedAccount( candidate ) ) {
                legalEntitiesInfo[candidate].paused = true;
                emit AccountPaused( candidate, 
                                    legalEntitiesInfo[candidate].RBBId,
                                    legalEntitiesInfo[candidate].CNPJ, 
                                    responsible );
            }
        }   
    }

/**
    * Unpause an account     
    * @param addr Ethereum address that needs to be validated
    */
    function unpauseAddress(address addr) public onlyWhenNotPaused onlyWhenNotExpired {

        address responsible = msg.sender;

        require ( responsible != addr , "Uma pessoa não é capaz de retirar o pause de sua própria conta");
        require( isResponsibleForRegistryValidation(responsible) , "Somente uma conta responsável validadora pode despausar outras contas" );        
        require( legalEntitiesInfo[addr].paused  , "Somente uma conta pausada pode ser despausada" ); 

        legalEntitiesInfo[addr].paused = false;
        
        emit AccountUnpaused(   addr, 
                                legalEntitiesInfo[addr].RBBId,
                                legalEntitiesInfo[addr].CNPJ, 
                                responsible);
    }

   /**
    * Invalidates the initial registry of a legal entity or the change of its registry
    * The invalidation can be called at any time in the lifecycle of the address (not only when it is WAITING_VALIDATION)
    * @param addr Ethereum address that needs to be validated
    */
    function invalidateRegistry(address addr) public onlyWhenNotPaused onlyWhenNotExpired {

        address responsible = msg.sender;

        require( legalEntitiesInfo[responsible].role == BlockchainAccountRole.ADMIN, "Apenas conta ADMIN pode invalidar contas. ");
        require( legalEntitiesInfo[addr].role != BlockchainAccountRole.SUPADMIN , "A conta SUPADMIN não pode ser invalidada");
        require( legalEntitiesInfo[addr].state != BlockchainAccountState.INVALIDATED, "A conta foi invalidada previamente." );

        legalEntitiesInfo[addr].state = BlockchainAccountState.INVALIDATED;
        
        emit AccountInvalidation(   addr, 
                                    legalEntitiesInfo[addr].RBBId, 
                                    legalEntitiesInfo[addr].CNPJ, 
                                    responsible );
    }

    function isResponsibleForRegistryValidation(address addr) public view returns (bool) {
        return ( legalEntitiesInfo[addr].role == BlockchainAccountRole.ADMIN || 
                 legalEntitiesInfo[addr].role == BlockchainAccountRole.SUPADMIN   );
    }

    function isOwner(address addr) public view returns (bool) {
        return owner()==addr;
    }

    function isAvailableAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.AVAILABLE;
    }

    function isWaitingValidationAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.WAITING_VALIDATION;
    }

    function isValidatedAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.VALIDATED;
    }

    function isInvalidated(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.INVALIDATED;
    }

    function isTheSameID(address a, address b) public view returns (bool) {
        return legalEntitiesInfo[a].CNPJ == legalEntitiesInfo[b].CNPJ ;
    }

    function isPaused(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].paused;
    }

    function isOperational(address addr) public view returns (bool) {
        return isValidatedAccount(addr) && !isPaused(addr);
    }

    function isRegistryOperational(uint CNPJ) public view returns (bool) {
        address[] memory addresses  = legalEntityId_To_Addr[CNPJ];

        for (uint i=0; i < addresses.length ; i++) {
            if (isOperational( addresses[i] ) 
                && legalEntitiesInfo[addresses[i]].role == BlockchainAccountRole.ADMIN  ) {
                    return true;
            }
        }
    }

    function getId (address addr) public view returns (uint) {
        return getRBBId(addr);
    }

    function getRBBId (address addr) public view returns (uint) {
        return legalEntitiesInfo[addr].RBBId;
    }

    function getCNPJ (address addr) public view returns (uint) {
        return legalEntitiesInfo[addr].CNPJ;
    }    

    function getRegistry (address addr) public view returns (uint, uint, bytes32, uint, uint, bool, uint256) {
        Registry memory reg = legalEntitiesInfo[addr];

        return (  reg.RBBId,
                  reg.CNPJ, 
                  reg.hashProof, 
                  (uint) (reg.state),
                  (uint) (reg.role),
                  reg.paused,
                  reg.dateTimeExpiration
                );
    }

    function getBlockchainAccounts(uint CNPJ) public view returns (address[] memory) {
        return legalEntityId_To_Addr[CNPJ];
    }

    function getAccountState(address addr) public view returns (int) {
        return ((int) (legalEntitiesInfo[addr].state));
    }

    function getAccountRole(address addr) public view returns (int) {
        return ((int) (legalEntitiesInfo[addr].role));
    }

   /**
    * The Owner can assign role SUPADMIN to anyone in the same LegalEntity
    * @param addr Ethereum address to be assigned the new role
    */
    function setRoleSupAdmin(address addr) public onlyOwner {
        require ( isTheSameID( owner(), addr ), "Owner só poderá atribuir o papel de SUPADMIN para contas do mesmo CNPJ" );

        BlockchainAccountRole roleBefore = legalEntitiesInfo[addr].role;
        legalEntitiesInfo[addr].role     = BlockchainAccountRole.SUPADMIN;                

        emit AccountRoleChange(   addr, 
                                  legalEntitiesInfo[addr].RBBId, 
                                  legalEntitiesInfo[addr].CNPJ, 
                                  msg.sender,
                                  roleBefore, 
                                  legalEntitiesInfo[addr].role  );
    }

    /**
    * The Owner can assign new default expiration time for future registries
    * @param dateTimeExpirationNew the new default expiration time 
    */
    function setDefaultDateTimeExpiration(uint256 dateTimeExpirationNew) public {

        require( legalEntitiesInfo[msg.sender].role == BlockchainAccountRole.SUPADMIN, "Apenas o SUPADMIN pode definir novo tempo de expiração de novos registros");

        require(dateTimeExpirationNew >= 0, "O tempo a expirar um registro deve ser maior ou igual a zero");

        uint256 dateTimeExpirationOld = defaultDateTimeExpiration;
        defaultDateTimeExpiration = dateTimeExpirationNew;
        
        emit RegistryExpirationChange(   msg.sender, 
                                         dateTimeExpirationOld, 
                                         defaultDateTimeExpiration );        
    }

    function getNextRBBId() private returns (uint) {
        return ++currentRBBId;
    } 

    function registryMock(uint CNPJ) public {
        
        address addr = msg.sender;
        bytes32 proofHash = 0;
        uint256 dateTimeExpiration = 4294967296; //2106 = 2^32 (Max 2^256 -1)
        uint RBBId = getNextRBBId();
        legalEntitiesInfo[addr] = Registry( RBBId, 
                                            CNPJ, 
                                            proofHash, 
                                            BlockchainAccountState.VALIDATED, 
                                            BlockchainAccountRole.ADMIN, 
                                            false,
                                            dateTimeExpiration );

        legalEntityId_To_Addr[CNPJ].push(addr);

        emit AccountRegistration(addr, RBBId, CNPJ, proofHash, dateTimeExpiration);
    }  
 

}
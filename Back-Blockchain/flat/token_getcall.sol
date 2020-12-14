// File: contracts/RBBLib.sol

pragma solidity ^0.6.0;

library RBBLib {

  function isEqual(string memory a, string memory b) public pure returns (bool) {
    bool r = keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    return r;
  }

  function bytesToBytes32(bytes memory _bytes) private pure returns (bytes32) {
        bytes32 out;
        uint _len= _bytes.length;
        if(_len>32){
            _len = 32;
        }
        for (uint i = 0; i < _len; i++) {
            out |= bytes32(_bytes[i]) >> (i * 8);
        }
        return out;
  }

  function stringBytes32(string memory _String ) pure public returns(bytes32  ){
        bytes memory _bytes = bytes(_String);
              
        return bytesToBytes32(_bytes);
       // bytes memory b = abi.encodePacked(a);
       
  } 


  function uintToStr(uint _i) public pure returns (string memory ) {
        uint number = _i;
        if (number == 0) {
            return "0";
        }
        uint j = number;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (number != 0) {
            bstr[k--] = byte(uint8(48 + number % 10));
            number /= 10;
        }
        return string(bstr);
  }
    
  function bytes32ToStr(bytes32 _bytes32) public pure returns (string memory) {


    bytes memory compare = new bytes(32);
    //bytes memory bytesArray = new bytes(32);
    bytes memory bytesArray = new bytes(1);
    string memory stringOut;
    for (uint256 i; i < 32; i++) {
        bytesArray[0] = _bytes32[i];
        if(bytesArray[0] != compare[i]){
            stringOut = string(abi.encodePacked(stringOut,string(bytesArray)));
            
        }
    }
    
    
    return stringOut;
    //return string(bytesArray);
    }


  function stringtoUint(string memory _string) pure public returns(uint256){
       uint256 outNumber;
       uint256 number;
       bytes memory b =bytes(_string);
        for(uint i=0;i<b.length;i++){
            outNumber = outNumber*10;
            number = (uint256(uint8(b[i])));
           // return number;
            require(number  > 47  && number < 58, "essa string não é um numero");
            number = number -48;
            outNumber = outNumber + number;
        }
       return outNumber;
   }



    

}

// File: @openzeppelin/contracts/GSN/Context.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts/RBBRegistry.sol

pragma solidity ^0.6.0;



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
        uint RBBId; //uma proxy para o CNPJ
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
        Links RBBID to Ethereum addresses.
     */
    mapping(uint => address[]) public RBBId_addresses;
    
    /**
     * Links CNPJ to its RBBID
     */
    mapping (uint => uint) public CNPJ_RBBId;

    event AccountRegistration       (address addr, uint RBBId, uint CNPJ, bytes32 hashProof, uint256 dateTimeExpiration);
    event AccountValidation         (address addr, uint RBBId, uint CNPJ, address responsible);
    event AccountInvalidation       (address addr, uint RBBId, uint CNPJ, address responsible);
    event AccountPaused             (address addr, uint RBBId, uint CNPJ, address responsible);
    event AccountUnpaused           (address addr, uint RBBId, uint CNPJ, address responsible);
    event AccountRoleChange         (address addr, uint RBBId, uint CNPJ, address responsible, BlockchainAccountRole roleBefore, BlockchainAccountRole roleNew);
    event RegistryExpirationChange  (address addr, uint256 dateTimeExpirationBefore, uint256 dateTimeExpirationNew);

    /* The responsible for the System-Admin is the Owner. It could be or not be the same address (SUPADMIN=owner) */
    constructor (uint CNPJSUPADMIN, string memory proofHashSUPADMIN, uint daysToExpire) public {                
        address addrSUPADMIN = msg.sender;
        bytes32 proofHash = RBBLib.stringBytes32(proofHashSUPADMIN);
        uint256 dateTimeExpiration = now + daysToExpire * 1 days; 
        uint RBBId = calculaProximoRBBID(CNPJSUPADMIN);
        legalEntitiesInfo[addrSUPADMIN] = Registry( RBBId, 
                                                    CNPJSUPADMIN, 
                                                    proofHash, 
                                                    BlockchainAccountState.VALIDATED, 
                                                    BlockchainAccountRole.SUPADMIN, 
                                                    false, 
                                                    dateTimeExpiration     );
        RBBId_addresses[RBBId].push(addrSUPADMIN);
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
        uint RBBId = calculaProximoRBBID(CNPJ);

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

        RBBId_addresses[RBBId].push(addr);
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
    function validateRegistry(address userAddr) public onlyWhenNotPaused onlyWhenNotExpired {

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

    function pauseLegalEntity(uint RBBId) public onlyWhenNotPaused {

        address responsible = msg.sender;
        address[] memory addresses  = RBBId_addresses[RBBId];

        require( legalEntitiesInfo[responsible].state == BlockchainAccountState.VALIDATED, "O responsável deve possuir uma conta Válida" );
        require( ( isSortOfAdmin(responsible) ), "O responsável deve possuir uma conta ADMIN ou SUPADMIN" );
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
        require( isSortOfAdmin(responsible) , "Somente uma conta responsável validadora pode despausar outras contas" );        
        require( isTheSameID(responsible, addr) 
                    || legalEntitiesInfo[responsible].role == BlockchainAccountRole.SUPADMIN , "Somente pode retirar pausa de uma conta quem for da mesma organização ou SUPADMIN" );
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

    function isSortOfAdmin(address addr) public view returns (bool) {
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

    function isRegistryOperational(uint RBBId) public view returns (bool) {
        address[] memory addresses  = RBBId_addresses[RBBId];

        for (uint i=0; i < addresses.length ; i++) {
            if ( isOperational( addresses[i] ) && isSortOfAdmin(addresses[i]) ) {
                    return true;
            }
        }
    }

    function getId (address addr) public view returns (uint) {
        uint RBBId = getRBBIdRaw(addr);
        require ( isRegistryOperational( RBBId ) , "A organizacao nao esta operacional" );
        return RBBId;
    }

    function getRBBIdRaw (address addr) public view returns (uint) {
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

    function getBlockchainAccounts(uint RBBId) public view returns (address[] memory) {
        return RBBId_addresses[RBBId];
    }

    function getAccountState(address addr) public view returns (int) {
        return ((int) (legalEntitiesInfo[addr].state));
    }

    function getAccountRole(address addr) public view returns (int) {
        return ((int) (legalEntitiesInfo[addr].role));
    }

    function getIdFromCNPJ(uint cnpj) public view returns (uint) {
        return CNPJ_RBBId[cnpj];
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

        uint256 dateTimeExpirationOld = defaultDateTimeExpiration;
        defaultDateTimeExpiration = dateTimeExpirationNew;
        
        emit RegistryExpirationChange(   msg.sender, 
                                         dateTimeExpirationOld, 
                                         defaultDateTimeExpiration );        
    }

    function calculaProximoRBBID(uint CNPJ) private returns (uint) {

        if ( CNPJ_RBBId[CNPJ] == 0 ) //se nao existir rbbid para este CNPJ
            CNPJ_RBBId[CNPJ] = ++currentRBBId;

        return CNPJ_RBBId[CNPJ];
    } 
 

}

// File: @openzeppelin/contracts/utils/Pausable.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor () internal {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: contracts/SpecificRBBToken.sol

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;





abstract contract SpecificRBBToken is Ownable, Pausable {

    RBBRegistry public registry;

    constructor () public {
    }

    function setInitializationDataDuringRegistration(address newRegistryAddr) public {
        registry = RBBRegistry(newRegistryAddr);
    }

    function getHashToMintedAccount(bytes32 specificHash) virtual public returns (bytes32);

    function verifyAndActForMint(uint idInvestor, bytes32 specificHash, uint amount, bytes32 docHash, 
            string[] memory data) virtual public;

    function verifyAndActForTransfer(address originalSender, uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash, string[] memory data) virtual public;

    function verifyAndActForRedeem(address originalSender, uint fromId, bytes32 fromHash, uint amount, bytes32 docHash, 
            string[] memory data) virtual public;
    
    function verifyAndActForRedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash, 
        string[] memory data) virtual public;


}

// File: contracts/SpecificRBBTokenRegistry.sol

pragma solidity ^0.6.0;





contract SpecificRBBTokenRegistry is Ownable {

    RBBRegistry public registry;

    //It starts with 1, because 0 is the id value returned when the item is not found in the Registry
    uint public idCount = 1;

    struct SpecificRBBTokenInfo {
        uint id;
        bool isActive;
    }

    constructor (address newRegistryAddr) public {
        registry = RBBRegistry(newRegistryAddr);
    }

    event SpecificRBBTokenRegistration (uint id, uint ownerId, address addr);
    event SpecificRBBTokenStateChange (uint id, bool state);

    //indexado pelo address pq serah a forma mais usada para consulta.
    mapping (address => SpecificRBBTokenInfo) public specificRBBTokensRegistry;


    function verifyTokenIsRegisteredAndActive(address addr) view public {
        require(containsSpecificRBBToken(addr), "Método só pode ser chamado por token específico previamente cadastrado");
        require(isSpecificRBBTokenActive(addr), "Método só pode ser chamado por token específico ativo");
    }

    function registerSpecificRBBToken (address specificRBBTokenAddr) public onlyOwner returns (uint)  {
        require (!containsSpecificRBBToken(specificRBBTokenAddr), "Token específico já registrado");

        SpecificRBBToken specificToken = SpecificRBBToken(specificRBBTokenAddr);
        specificToken.setInitializationDataDuringRegistration(address(registry));
        address scOwnerAddr = specificToken.owner();
        uint scOwnerId = registry.getId(scOwnerAddr);

        specificRBBTokensRegistry[specificRBBTokenAddr] = SpecificRBBTokenInfo(idCount, true);
        emit SpecificRBBTokenRegistration (idCount, scOwnerId, specificRBBTokenAddr);
        idCount++;
    }

    function getSpecificRBBTokenId (address addr) public view returns (uint) {
        require (containsSpecificRBBToken(addr), "Token específico nao registrado");
        SpecificRBBTokenInfo memory info = specificRBBTokensRegistry[addr];
        return info.id;
    }

    function getSpecificRBBTokenIdAndOwnerId (address addr) public view returns (uint, uint) {
        require (containsSpecificRBBToken(addr), "Token específico nao registrado");
        SpecificRBBTokenInfo memory info = specificRBBTokensRegistry[addr];
        SpecificRBBToken specificToken = SpecificRBBToken(addr);
        address scOwnerAddr = specificToken.owner();
        uint scOwnerId = registry.getId(scOwnerAddr);

        return (info.id, scOwnerId);
    }
    
    function getSpecificOwnerId (address addr) public view returns (uint) {
        require (containsSpecificRBBToken(addr), "Token específico nao registrado");
        SpecificRBBToken specificToken = SpecificRBBToken(addr);
        address scOwnerAddr = specificToken.owner();
        uint scOwnerId = registry.getId(scOwnerAddr);

        return scOwnerId;
    }    

    function containsSpecificRBBToken(address addr) private view returns (bool) {
        SpecificRBBTokenInfo memory info = specificRBBTokensRegistry[addr];
        if (info.id!=0) return true;
        else return false;
    }

    function isSpecificRBBTokenActive(address addr) public view returns (bool) {
        require (containsSpecificRBBToken(addr), "Token específico nao registrado");
        SpecificRBBTokenInfo memory info = specificRBBTokensRegistry[addr];
        return info.isActive;
    }

    function setStatus(address addr, bool status) public onlyOwner returns (bool) {
        require (containsSpecificRBBToken(addr), "Token específico nao registrado");
        SpecificRBBTokenInfo storage info = specificRBBTokensRegistry[addr];
        info.isActive = status;
        emit SpecificRBBTokenStateChange(info.id, info.isActive);
    }
}

// File: @openzeppelin/contracts/math/SafeMath.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: contracts/RBBToken.sol

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;








contract RBBToken is Pausable, Ownable {

//TODO: avaliar se deveria ter um set para modificar esses atributos. Ideal seria mudar apenas pela governanca
    SpecificRBBTokenRegistry public tokenRegistry;
    RBBRegistry public registry;


    using SafeMath for uint;

    uint8 public decimals = 2;

    address public responsibleForInvestmentConfirmation;
    address public responsibleForSettlement;


    //specificTokenId => (RBBid => (specificHash => amount)
    mapping (uint => mapping (uint => mapping (bytes32 => uint))) public rbbBalances;

    //specificTokenId => (specificHash => amount)
    mapping (uint => mapping (bytes32 => uint)) public balanceRequestedTokens;

    event RBBTokenMintRequested(address specificTokenAddr, bytes32 specificHash, uint idInvestor, 
            uint amount, bytes32 docHash);
    event RBBTokenMint(address specificTokenAddr, bytes32 specificHash, uint amount, bytes32 docHash, string[] data);
    event RBBTokenBurn(address specificTokenAddr, address originalSender, uint fromId, bytes32 fromHash, 
            uint amount, bytes32 docHash);
    event RBBTokenTransfer (address specificTokenAddr, address originalSender, uint fromId, bytes32 fromHash, uint toId,
            bytes32 toHash, uint amount, bytes32 docHash, string[] data);
    event RBBTokenRedemptionRequested (address specificTokenAddr, address originalSender, uint fromId, bytes32 fromHash, 
            uint amount, bytes32 docHash, string[] data);
    event RBBTokenRedemptionSettlement(address specificTokenAddr, bytes32 redemptionTransactionHash, 
            bytes32 docHash, string[] data);

    event ManualIntervention_RoleOrAddress(address account, uint8 eventType);


    constructor (address newRegistryAddr, address newSpecificRBBTokenAddr, uint8 _decimals) public {
        registry = RBBRegistry(newRegistryAddr);
        tokenRegistry = SpecificRBBTokenRegistry(newSpecificRBBTokenAddr);
        decimals = _decimals;
        responsibleForInvestmentConfirmation = msg.sender;
        responsibleForSettlement = msg.sender;

    }

///******************************************************************* */

    function requestMint(bytes32 specificInvestimentHash, uint idInvestor, uint amount, bytes32 docHash) 
        public {
    
        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        address specificTokenAddr = msg.sender;

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);
        
        uint specificTokenId = tokenRegistry.getSpecificRBBTokenId(specificTokenAddr);

        balanceRequestedTokens[specificTokenId][specificInvestimentHash] = 
            balanceRequestedTokens[specificTokenId][specificInvestimentHash].add(amount);
    
        emit RBBTokenMintRequested(specificTokenAddr, specificInvestimentHash, idInvestor, amount, docHash);

    }

    function mint(address specificTokenAddr, uint idInvestor, bytes32 specificHash, uint amount, bytes32 docHash,
        string[] memory data) public {

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        require (responsibleForInvestmentConfirmation == msg.sender, 
            "Somente um responsável pela confirmação de investimento pode enviar a transação");

        require(amount>0, "Valor a mintar deve ser maior do que zero");

        (uint specificTokenId, uint specificTokenOwnerId) = 
                    tokenRegistry.getSpecificRBBTokenIdAndOwnerId(specificTokenAddr);

        balanceRequestedTokens[specificTokenId][specificHash] 
            = balanceRequestedTokens[specificTokenId][specificHash].sub(amount, "Total de emissão excede valor solicitado");

        SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);

        //Retorna a conta de mint associada ao hash especifico. 
        bytes32 calcHash = specificToken.getHashToMintedAccount(specificHash);

        rbbBalances[specificTokenId][specificTokenOwnerId][calcHash] = 
            rbbBalances[specificTokenId][specificTokenOwnerId][calcHash].add(amount);

        specificToken.verifyAndActForMint(idInvestor, specificHash, amount, docHash, data);

        emit RBBTokenMint(specificTokenAddr, specificHash, amount, docHash, data);
    }


    function burnOwnTokenBySpecificTokens (address originalSender, bytes32 hashToBurn, uint amount, 
        bytes32 docHash) public {

        address specificTokenAddr = msg.sender;
        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        uint specificTokenOwnerId = tokenRegistry.getSpecificOwnerId(specificTokenAddr);
        
        _burn(specificTokenAddr, originalSender, specificTokenOwnerId, hashToBurn, amount, docHash);

    }


    function burnOwnToken (address specificTokenAddr, bytes32 hashToBurn, uint amount, bytes32 docHash) 
        public {

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        uint idToBurn = registry.getId(msg.sender);

        _burn(specificTokenAddr, msg.sender, idToBurn, hashToBurn, amount, docHash);

    }

    function _burn(address specificTokenAddr, address originalSender, uint fromId, bytes32 fromHash, 
        uint amount, bytes32 docHash) internal {
        
        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);
//        require(amount>0, "Valor a queimar deve ser maior do que zero");

        uint specificTokenId = tokenRegistry.getSpecificRBBTokenId(specificTokenAddr);

        rbbBalances[specificTokenId][fromId][fromHash] = 
            rbbBalances[specificTokenId][fromId][fromHash].sub(amount, "Total de tokens a serem queimados é maior do que o balance");

        emit RBBTokenBurn(specificTokenAddr, originalSender, fromId, fromHash, amount, docHash);
    }

///******************************************************************* */


    function transfer (address specificTokenAddr, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash, string[] memory data) public whenNotPaused {

        uint fromId = registry.getId(msg.sender);

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

//        require(registry.isRegistryOperational(fromId), "Conta de origem precisa estar com cadastro validado");
//        require(registry.isRegistryOperational(toId), "Conta de destino precisa estar com cadastro validado");
        uint specificTokenId = tokenRegistry.getSpecificRBBTokenId(specificTokenAddr);

        SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);
        specificToken.verifyAndActForTransfer(msg.sender, fromId, fromHash, toId, toHash, amount, docHash, data);

        //altera valores de saldo
        rbbBalances[specificTokenId][fromId][fromHash] =
                rbbBalances[specificTokenId][fromId][fromHash].sub(amount, "Saldo da origem não é suficiente para a transferência");
        rbbBalances[specificTokenId][toId][toHash] = rbbBalances[specificTokenId][toId][toHash].add(amount);

        emit RBBTokenTransfer (specificTokenAddr, msg.sender, fromId, fromHash, toId, toHash, amount, docHash, data);

    }

    function redeem (address specificTokenAddr, bytes32 fromHash, uint amount, 
        bytes32 docHash, string[] memory data) public whenNotPaused  {

            uint fromId = registry.getId(msg.sender);

            tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

//            require(registry.isRegistryOperational(fromId), "Conta solicitante do redeem precisa estar com cadastro validado");
            require(amount>0, "Valor a resgatar deve ser maior do que zero");
    
            SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);
            specificToken.verifyAndActForRedeem(msg.sender, fromId, fromHash, amount, docHash, data);

            emit RBBTokenRedemptionRequested(specificTokenAddr, msg.sender, fromId, fromHash, amount, docHash, data);
            _burn(specificTokenAddr, msg.sender, fromId, fromHash, amount, docHash);
    }

   /**
    * Using this function, the Responsible for Settlement indicates that he has made the FIAT money transfer.
    * @ param redemptionTransactionHash hash of the redeem transaction in which the FIAT money settlement occurred.
    * @ param receiptHash hash that proof the FIAT money transfer
    */ 
    function notifyRedemptionSettlement(address specificTokenAddr, bytes32 redemptionTransactionHash, 
        bytes32 docHash, string[] memory data) public whenNotPaused {

        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        require (responsibleForSettlement == msg.sender, 
            "Somente um responsável pela liquidição pode enviar a transação");

        SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);
        specificToken.verifyAndActForRedemptionSettlement(redemptionTransactionHash, docHash, data);

        emit RBBTokenRedemptionSettlement(specificTokenAddr, redemptionTransactionHash, docHash, data);
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

// File: contracts/ESGBndesToken_BNDESRoles.sol

pragma solidity ^0.6.0;




contract ESGBndesToken_BNDESRoles is Ownable {

    RBBRegistry public registry;

    address public responsibleForInitialAllocation;
    address public responsibleForDisbursement;
    address public resposibleForApproveExtraordinaryTransfers;
    address public resposibleForPayingBNDESSuppliers;

    event FA_ManualIntervention_RoleOrAddress(address account, uint8 eventType);

    constructor (address newRegistryAddr) public {

        registry = RBBRegistry(newRegistryAddr);

        responsibleForInitialAllocation = msg.sender;
        responsibleForDisbursement = msg.sender;
        resposibleForApproveExtraordinaryTransfers = msg.sender;
        resposibleForPayingBNDESSuppliers = msg.sender;

    } 

    function setResponsibleForInitialAllocation(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pela alocação inicial deve ser da mesmo RBB_ID do contrato");
        responsibleForInitialAllocation = rs;
        emit FA_ManualIntervention_RoleOrAddress(rs, 1);
    }

    function setResponsibleForDisbursement(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pelo desembolso deve ser da mesmo RBB_ID do contrato");
        responsibleForDisbursement = rs;
        emit FA_ManualIntervention_RoleOrAddress(rs, 2);
    }

    function setResposibleForApproveExtraordinaryTransfers(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pelo cadastramento de transferencias extraordinárias deve ser da mesmo RBB_ID do contrato");
        resposibleForApproveExtraordinaryTransfers = rs;
        emit FA_ManualIntervention_RoleOrAddress(rs, 3);
    }

    function setResposibleForPayingBNDESSuppliers(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner()), "O responsável pelo pagamento direto a suppliers deve ser da mesmo RBB_ID do contrato");
        resposibleForPayingBNDESSuppliers = rs;
        emit FA_ManualIntervention_RoleOrAddress(rs, 4);
    }



}

// File: contracts/ESGBndesToken.sol

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;










/*
Todas as operações já supõem que a entidade de origem e destino estão cadastradas e validadas no RBB_Registry, pois isso é garantido pelo contrato genérico (RBB_Token)
Não incluído (TBD):
------------
- requisito adicional de o cliente poder resgatar uma parte do valor (ao invés de ter que necessariamente transferir tudo ao fornecedor)
- ideia de o fornecedor poder sacar mais de um saldo ao mesmo tempo.
- pedido inicial de financiamento do cliente 
- devolução de fornecedor para cliente sem anuência para o BNDES
- controle que cada doacao realmente se transformou em duas transacoes, uma para a conta adm e outra para a conta usual
uint admFee = amount.mul(bndesFee).div(100);
- período de validade para as autorizações de transferências extraordinárias
- invalidar doador, cliente e fornecedor (por exemplo, em caso de CNPJ deixar de existir, contrato com BNDES acabar ou periodicamente)
- permitir criar perfis diferenciados para contas dos clientes e fornecedores
- incluir possibilidade de remover doadores, clientes e, talvez, fornecedores
*/
contract ESGBndesToken is SpecificRBBToken {

    RBBToken public rbbToken;
    ESGBndesToken_BNDESRoles public bndesRoles;

    //RBBId investor => true/false (registered or not)
    mapping (uint => bool) public investors;

    //RBBId client => (idFinancialSupportAgreement Client => true/false (registered or not)
    mapping (uint => mapping (string => bool)) public clients;
    mapping (bytes32 => string) public hashToIdFinancialSupportAgreement;

    //RBBId supplier => true/false (registered or not)
    mapping (uint => bool) public suppliers;

    //Hash of approved Extraordinary Transfers
    bytes32[] public hashApprovedExtraordinaryTransfers;

    // BNDES Fee percentage
//   uint256 public bndesFee;    

    //Types of transfer operation
    string public INITIAL_ALLOCATION = "INITIAL_ALLOCATION";
    string public DISBURSEMENT_VERIFICATION = "DISBURSEMENT_VERIFICATION";
    string public CLIENT_PAY_SUPPLIER_VERIFICATION = "CLIENT_PAY_SUPPLIER_VERIFICATION";
    string public BNDES_PAY_SUPPLIER_VERIFICATION = "BNDES_PAY_SUPPLIER_VERIFICATION";
    string public EXTRAORDINARY_TRANSFERS = "EXTRAORDINARY_TRANSFERS";


    uint8 public RESERVED_MINTED_ACCOUNT = 0;
    uint8 public RESERVED_USUAL_DISBURSEMENTS_ACCOUNT = 1;
    uint8 public RESERVED_BNDES_ADMIN_FEE_TO_HASH = 2;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_INVESTOR = 10;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER = 20;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY = 30;

    using SafeMath for uint;
   
    event FA_InvestmentBooked(uint idInvestor, uint amount, bytes32 docHash);
    event FA_InvestmentConfirmed(uint idInvestor, uint amount, bytes32 docHash);

    event FA_InitialAllocation_Disbursements(uint amount, bytes32 docHash);
    event FA_InitialAllocation_Fee(uint amount, bytes32 docHash);

    event FA_Disbursement  (uint idClient, string idFinancialSupportAgreement, uint amount, bytes32 docHash);
    event FA_TokenTransfer (uint fromId, string fromIdFinancialSupportAgreement, uint toId, uint amount, bytes32 docHash);
    event FA_BNDES_TokenTransfer(uint toId, uint amount, bytes32 docHash);
    event FA_RedemptionRequested (uint idClaimer, uint amount, bytes32 docHash);
    event FA_RedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash);
 
    event FA_ExtraordinaryTransferAllowed (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);
    event FA_ExtraordinaryTransferExecuted(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);

//    event FA_ManualIntervention_Fee(uint256 percent, bytes32 docHash);

    event FA_InvestorAdded(uint id);
    event FA_ClientAdded(uint id);
    event FA_SupplierAdded(uint registeredBy, uint id);


    constructor (address newrbbTokenAddr, address addrBndesRoles) public {
//        require (fee < 100, "Valor de Fee maior que 100%");

        rbbToken = RBBToken(newrbbTokenAddr);
        bndesRoles = ESGBndesToken_BNDESRoles(addrBndesRoles);

//        bndesFee = fee;
    }

/*
    function setBNDESFee(uint256 newBndesFee, bytes32 docHash) public onlyOwner {
        require (newBndesFee < 100, "Valor de Fee maior que 100%");
        bndesFee = newBndesFee;
        emit FA_ManualIntervention_Fee(newBndesFee, docHash);
    }
*/

    function bookInvestment(uint amount, bytes32 docHash) public whenNotPaused  {        
        
        uint idInvestor = registry.getId(msg.sender);

        require (investors[idInvestor], "Somente investidores cadastrados podem executar essa ação");
 //       require(registry.isRegistryOperational(idInvestor), "Conta de investidor precisa estar com cadastro validado");
        
        bytes32 specificHash = getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY);
        rbbToken.requestMint(specificHash, idInvestor, amount, docHash);

        emit FA_InvestmentBooked(idInvestor, amount, docHash);
    }
    
    function verifyAndActForMint(uint idInvestor, bytes32 specificHash, uint amount, bytes32 docHash,
        string[] memory data) public override whenNotPaused onlyRBBToken {

        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY)==specificHash, "Erro no cálculo do hash da doação");

        require (investors[idInvestor], "Deveria ser um investidor, registro estah incorreto");

        emit FA_InvestmentConfirmed(idInvestor, amount, docHash);

    }


    function getHashToMintedAccount(bytes32 specificHash) override public returns (bytes32) {
        //There is no difference of specificHash, all money should be minted in the same account
        return getCalculatedHash(RESERVED_MINTED_ACCOUNT);
    }

    function verifyAndActForTransfer(address originalSender, uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash, string[] memory data) public override whenNotPaused onlyRBBToken {

        string memory specificMethod = data[0];

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");

        if (RBBLib.isEqual(INITIAL_ALLOCATION, specificMethod)) {
            verifyAndActForTransfer_INITIAL_ALLOCATION(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else if (RBBLib.isEqual(DISBURSEMENT_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_DISBURSEMENT(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else if (RBBLib.isEqual(CLIENT_PAY_SUPPLIER_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_CLIENT_PAY_SUPPLIER(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else if (RBBLib.isEqual(BNDES_PAY_SUPPLIER_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_BNDES_PAY_SUPPLIER(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else if (RBBLib.isEqual(EXTRAORDINARY_TRANSFERS, specificMethod)) {
            verifyAndActForTransfer_EXTRAORDINARY_TRANSFERS(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else {
            require (false, "Nenhuma verificação específica encontrada para a transferência");
        }

    }

    function verifyAndActForTransfer_INITIAL_ALLOCATION(address originalSender, uint fromId, bytes32 fromHash, uint toId, 
            bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {

        require (bndesRoles.responsibleForInitialAllocation() == originalSender, 
            "Somente um responsável pelas alocações iniciais pode enviar a transação");

        uint ownerId = registry.getId(owner());
        require (fromId == ownerId, "Id de origem da transação não está igual ao do owner do contrato");
        require (fromHash == getCalculatedHash(RESERVED_MINTED_ACCOUNT), "Hash de origem da transação não está correto");

        require (fromId == toId, "Id de destino da transação não está igual ao do owner do contrato");

        if (toHash == getCalculatedHash(RESERVED_USUAL_DISBURSEMENTS_ACCOUNT)) {
            emit FA_InitialAllocation_Disbursements(amount, docHash);
        }
        else if (toHash == getCalculatedHash(RESERVED_BNDES_ADMIN_FEE_TO_HASH)) {
            emit FA_InitialAllocation_Fee(amount, docHash);
        }
        else {
            require (false, "Hash de destino não está correspondente a conta de desembolso ou de adm");
        }
    }

    function verifyAndActForTransfer_DISBURSEMENT(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];
        uint ownerId = registry.getId(owner());

        require (originalSender == bndesRoles.responsibleForDisbursement(), 
            "Esta transação só pode ser executada pelo responsável pelo desembolso");

        //Essa eh uma regra especifica visto que outra organizacao pode ter recebido o token no allocate.
        require (fromId == ownerId, "Id de origem da transação não está igual ao do owner do contrato");
        require (getCalculatedHash(RESERVED_USUAL_DISBURSEMENTS_ACCOUNT)==fromHash, "Erro no cálculo do hash da conta do BNDES");
        require (getCalculatedHash(idFinancialSupportAgreement)==toHash, "Erro no cálculo do hash da conta do cliente");

        addClient(toId, idFinancialSupportAgreement);

        emit FA_Disbursement (toId, idFinancialSupportAgreement, amount, docHash);

    }   

    function verifyAndActForTransfer_CLIENT_PAY_SUPPLIER(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        //nao verifica o sender, dado que o esse contrato nao diferencia as contas do cliente

        require (clients[fromId][idFinancialSupportAgreement], "Somente clientes em contratos cadastrados podem executar o pagamento");
        require (getCalculatedHash(idFinancialSupportAgreement)==fromHash, "Erro no cálculo do hash da conta do cliente");
        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER)==toHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId,
            "Um instituição não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        addSupplier (fromId, toId);

        emit FA_TokenTransfer (fromId, idFinancialSupportAgreement, toId, amount, docHash);

    }

    function verifyAndActForTransfer_BNDES_PAY_SUPPLIER(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {
        require (fromId==registry.getId(owner()), "Somente o BNDES pode executar o pagamento");
        require (originalSender == bndesRoles.resposibleForPayingBNDESSuppliers(), 
            "Esta transação só pode ser executada pelo responsável pelo do pagamento de fornecedores do BNDES");
        require (getCalculatedHash(RESERVED_BNDES_ADMIN_FEE_TO_HASH)==fromHash, "Erro no cálculo do hash da conta de admin do contrato especifico");
        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER)==toHash, "Erro no cálculo do hash da conta do fornecedor");
        require(fromId != toId, "Um BNDES não pode transferir token para si");

        addSupplier (fromId, toId);

        emit FA_BNDES_TokenTransfer (toId, amount, docHash);

    }



    function verifyAndActForRedeem(address originalSender, uint fromId, bytes32 fromHash, uint amount, 
        bytes32 docHash, string[] memory data) public override whenNotPaused onlyRBBToken {

        //nao verifica o sender, dado que o esse contrato nao diferencia as contas do fornecedor

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        require (suppliers[fromId], "Somente fornecedores podem executar o pagamento");
        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER)==fromHash, "Erro no cálculo do hash da conta do fornecedor");

        emit FA_RedemptionRequested (fromId, amount, docHash);

    }

    function verifyAndActForRedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash, 
        string[] memory data)
        public override whenNotPaused onlyRBBToken {

        emit FA_RedemptionSettlement (redemptionTransactionHash, docHash);
    }

    modifier onlyRBBToken() {
        require (msg.sender==address(rbbToken), "Esse método só pode ser chamado pelo RBB_Token");
        _;
    }

    
    function getCalculatedHash (uint info) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }

    function getCalculatedHash (string memory info) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }

    function authorizeExtraordinaryTransfer (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
                uint amount, bytes32 docHash) public  {
        
        require (bndesRoles.resposibleForApproveExtraordinaryTransfers() == msg.sender, 
            "Somente um responsável pelas transferências extraordinárias por enviar a transação");  
        require (hasRoleInThisContract(fromId, fromHash), "Endereço de origem não incluído como papel nesse cadastro");
        require (hasRoleInThisContract(toId, toHash), "Endereço de destino não incluído como papel nesse cadastro");

        bytes32 m = keccak256(abi.encodePacked(fromId, fromHash, toId, toHash, amount));
        hashApprovedExtraordinaryTransfers.push(m);

        emit FA_ExtraordinaryTransferAllowed (fromId, fromHash, toId, toHash, amount, docHash);

    }
   
    function verifyAndActForTransfer_EXTRAORDINARY_TRANSFERS(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {

        require (hasRoleInThisContract(fromId, fromHash), "Endereço de origem não incluído como papel nesse cadastro");
        require (hasRoleInThisContract(toId, toHash), "Endereço de destino não incluído como papel nesse cadastro");

        bytes32 m = keccak256(abi.encodePacked(fromId, fromHash, toId, toHash, amount));

        bool transferApproved = false;
        uint index = 0;
        for (; index<hashApprovedExtraordinaryTransfers.length; index++) {
            if (hashApprovedExtraordinaryTransfers[index] == m) {
                transferApproved = true;
                break;
            }
        }

        require (transferApproved, "Intervenção manual não previamente cadastrada");

        hashApprovedExtraordinaryTransfers[index] 
            = hashApprovedExtraordinaryTransfers [hashApprovedExtraordinaryTransfers.length-1];
        hashApprovedExtraordinaryTransfers.pop();

        emit FA_ExtraordinaryTransferExecuted (fromId, fromHash, toId, toHash, amount, docHash);

    }

//////////

    function addInvestor (uint idInvestor) public onlyOwner {
        require(registry.isRegistryOperational(idInvestor), "Conta de investidor precisa estar com cadastro validado");
        if(!investors[idInvestor]) {
            investors[idInvestor] = true;
            emit FA_InvestorAdded(idInvestor);
        }
    }


    function addClient (uint id, string memory idFinancialSupportAgreement) internal  {

        if (!clients[id][idFinancialSupportAgreement]) {
            clients[id][idFinancialSupportAgreement] = true; //register the client
            bytes32 h = getCalculatedHash(idFinancialSupportAgreement);
            hashToIdFinancialSupportAgreement[h] = idFinancialSupportAgreement;
            emit FA_ClientAdded(id);

        }
    }


    function addSupplier (uint registererId, uint idSupplier) internal  {

        if (!suppliers[idSupplier]) {
            suppliers[idSupplier] = true; //register the supplier
            emit FA_SupplierAdded(registererId, idSupplier);
        }
    }

    function hasRoleInThisContract (uint rbbId, bytes32 hashToAccount) private view returns (bool) {

        if (investors[rbbId]==true) return true;

        string memory idFinancialSupportAgreement = hashToIdFinancialSupportAgreement[hashToAccount];
        if (clients[rbbId][idFinancialSupportAgreement]==true) return true;

        if (suppliers[rbbId]==true) return true;

        uint ownerId = registry.getId(owner());
        if (ownerId == rbbId) return true;

        uint rbbTokenOwnerId = registry.getId(rbbToken.owner());
        if (rbbTokenOwnerId == rbbId) return true;

        return false;
    }

}

// File: contracts/ESGBndesToken_GetDataToCall.sol

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;



contract ESGBndesToken_GetDataToCall  {

    ESGBndesToken token;

    constructor (address addr) public {
        token = ESGBndesToken(addr);
    }

    function getInitialAllocationToDisbusementData () public view
        returns (bytes32, bytes32, string[] memory)  {

        bytes32 fromHash = getCalculatedHashUint(token.RESERVED_MINTED_ACCOUNT());
        bytes32 toHash = getCalculatedHashUint(token.RESERVED_USUAL_DISBURSEMENTS_ACCOUNT());

        string[] memory data = new string[](1);
        data[0] = token.INITIAL_ALLOCATION();
        return (fromHash, toHash, data);
    }

    function getInitialAllocationToChargeFeeData () public view
        returns (bytes32, bytes32, string[] memory)  {

        bytes32 fromHash = getCalculatedHashUint(token.RESERVED_MINTED_ACCOUNT());
        bytes32 toHash = getCalculatedHashUint(token.RESERVED_BNDES_ADMIN_FEE_TO_HASH());

        string[] memory data = new string[](1);
        data[0] = token.INITIAL_ALLOCATION();
        return (fromHash, toHash, data);
    }

    function getDisbusementData (string memory idFinancialSupportAgreement) public view
        returns (bytes32, bytes32, string[] memory)  {

        bytes32 fromHash = getCalculatedHashUint(token.RESERVED_USUAL_DISBURSEMENTS_ACCOUNT());
        bytes32 toHash = getCalculatedHashString(idFinancialSupportAgreement);

        string[] memory data = new string[](2);
        data[0] = token.DISBURSEMENT_VERIFICATION();
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

    function getClientPaySupplierData (string memory idFinancialSupportAgreement) public view
            returns (bytes32, bytes32, string[] memory) {

        bytes32 fromHash = getCalculatedHashString(idFinancialSupportAgreement);
        bytes32 toHash = getCalculatedHashUint(token.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER());

        string[] memory data = new string[](2);
        data[0] = token.CLIENT_PAY_SUPPLIER_VERIFICATION();
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

    function getBNDESPaySupplierData () public view
            returns (bytes32, bytes32, string[] memory) {

        bytes32 fromHash = getCalculatedHashUint(token.RESERVED_BNDES_ADMIN_FEE_TO_HASH());
        bytes32 toHash = getCalculatedHashUint(token.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER());

        string[] memory data = new string[](1);
        data[0] = token.BNDES_PAY_SUPPLIER_VERIFICATION();
        return (fromHash, toHash, data);
    }

    function getRedeemData () view public 
            returns (bytes32, string[] memory) {

        bytes32 fromHash = getCalculatedHashUint(token.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER());

        string[] memory data = new string[](0);
        return (fromHash, data);
    }

    //Não criei getNotifyRedepmtion data porque não tinha nada especifico a fazer.

    function getCalculatedHashUint (uint info) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }
    function getCalculatedHashString (string memory info) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }


}

// File: @openzeppelin/contracts/GSN/Context.sol

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
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts/ownership/Ownable.sol

pragma solidity ^0.6.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
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
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

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

// File: contracts/RBBRegistry.sol

pragma solidity ^0.6.0;



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
        bytes32 idProofHash; //hash of declaration
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

/*
    event AccountRegistration(address addr, uint id,  string idProofHash);
    event AccountChange(address oldAddr, address newAddr, uint id, string idProofHash);
    event AccountValidation(address addr, uint id);
    event AccountInvalidation(address addr, uint id);
*/
    constructor (uint idResposibleForValidation) public {
        responsibleForRegistryValidation = msg.sender;
        legalEntitiesInfo[msg.sender] = LegalEntityInfo(idResposibleForValidation, "", BlockchainAccountState.VALIDATED);
        legalEntityId_To_Addr[idResposibleForValidation] = responsibleForRegistryValidation;
//        emit AccountRegistration(msg.sender, idResposibleForValidation, "");
    }

/*
    function registryLegalEntity(uint cnpj, bytes32 idProofHash)
        public {
        
        address addr = msg.sender;

        // Endereço não pode ter sido cadastrado anteriormente
        require (isAvailableAccount(addr), "Endereço não pode ter sido cadastrado anteriormente");

//?? Avaliar se essa verificacao serah feita

        address account = getBlockchainAccount(cnpj);

        require (isAvailableAccount(account), "CNPJ Já está associado. Use a função Troca.");

        legalEntitiesInfo[addr] = LegalEntityInfo(cnpj, idProofHash, BlockchainAccountState.WAITING_VALIDATION);

        legalEntityId_To_Addr[cnpj] = addr;

        emit AccountRegistration(addr, cnpj, idProofHash);
    }



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
*/
    function isValidatedAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.VALIDATED;
    }

    function isValidatedId(uint id) public view returns (bool) {
        address addr = getBlockchainAccount(id);
        return isValidatedAccount(addr);
    }
/*
    function isInvalidatedByValidatorAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.INVALIDATED_BY_VALIDATOR;
    }

    function isInvalidatedByChangeAccount(address addr) public view returns (bool) {
        return legalEntitiesInfo[addr].state == BlockchainAccountState.INVALIDATED_BY_CHANGE;
    }

    function getResponsibleForRegistryValidation() public view returns (address) {
        return responsibleForRegistryValidation;
    }
*/
    function getId (address addr) public view returns (uint) {
        return legalEntitiesInfo[addr].id;
    }
/*
    function getLegalEntityInfo (address addr) public view returns (uint, string memory, uint, address) {
        return (legalEntitiesInfo[addr].id, legalEntitiesInfo[addr].idProofHash, (uint) (legalEntitiesInfo[addr].state),
             addr);
    }
*/
    function getBlockchainAccount(uint cnpj) public view returns (address) {
        return legalEntityId_To_Addr[cnpj];
    }
/*
    function getLegalEntityInfoById (uint cnpj) public view
        returns (uint, string memory, uint, address) {
        
        address addr = getBlockchainAccount(cnpj);
        return getLegalEntityInfo (addr);
    }

    function getAccountState(address addr) public view returns (int) {
        return ((int) (legalEntitiesInfo[addr].state));
    }
*/
    function registryMock(uint cnpj)
        public {
        
        address addr = msg.sender;
        bytes32 idProofHash = 0x00;

        legalEntitiesInfo[addr] = LegalEntityInfo(cnpj, idProofHash, BlockchainAccountState.VALIDATED);

        legalEntityId_To_Addr[cnpj] = addr;

//        emit AccountRegistration(addr, cnpj, idProofHash);
    }


}

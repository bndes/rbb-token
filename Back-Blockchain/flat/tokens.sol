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

// File: @openzeppelin/contracts/access/Roles.sol

pragma solidity ^0.6.0;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

// File: @openzeppelin/contracts/access/roles/PauserRole.sol

pragma solidity ^0.6.0;



contract PauserRole is Context {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor () internal {
        _addPauser(_msgSender());
    }

    modifier onlyPauser() {
        require(isPauser(_msgSender()), "PauserRole: caller does not have the Pauser role");
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyPauser {
        _addPauser(account);
    }

    function renouncePauser() public {
        _removePauser(_msgSender());
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
    }
}

// File: @openzeppelin/contracts/lifecycle/Pausable.sol

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
contract Pausable is Context, PauserRole {
    /**
     * @dev Emitted when the pause is triggered by a pauser (`account`).
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by a pauser (`account`).
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state. Assigns the Pauser role
     * to the deployer.
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
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    function unpause() public onlyPauser whenPaused {
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
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: contracts/RBBToken.sol

pragma solidity ^0.6.0;








contract RBBToken is Pausable, Ownable {

//TODO: avaliar se deveria ter um set para modificar esses atributos
    SpecificRBBTokenRegistry tokenRegistry;
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

        (uint specificTokenId, uint businessContractOwnerId) = 
                    tokenRegistry.getSpecificRBBTokenIdAndOwnerId(specificTokenAddr);

        balanceRequestedTokens[specificTokenId][specificHash] 
            = balanceRequestedTokens[specificTokenId][specificHash].sub(amount, "Total de emissão excede valor solicitado");

        SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);

        //Retorna a conta de mint associada ao hash especifico. 
        bytes32 calcHash = specificToken.getHashToMintedAccount(specificHash);

        rbbBalances[specificTokenId][businessContractOwnerId][calcHash] = 
            rbbBalances[specificTokenId][businessContractOwnerId][calcHash].add(amount);

        specificToken.verifyAndActForMint(idInvestor, specificHash, amount, docHash, data);

        emit RBBTokenMint(specificTokenAddr, specificHash, amount, docHash, data);
    }


    function burnOwnTokenBySpecificTokens (address originalSender, bytes32 hashToBurn, uint amount, 
        bytes32 docHash) public {

        address specificTokenAddr = msg.sender;
        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        (uint specificTokenId, uint businessContractOwnerId) = 
                    tokenRegistry.getSpecificRBBTokenIdAndOwnerId(specificTokenAddr);
        
        _burn(specificTokenAddr, originalSender, businessContractOwnerId, hashToBurn, amount, docHash);

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

        require(registry.isValidatedId(fromId), "Conta de origem precisa estar com cadastro validado");
        require(registry.isValidatedId(toId), "Conta de destino precisa estar com cadastro validado");
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

            require(registry.isValidatedId(fromId), "Conta solicitante do redeem precisa estar com cadastro validado");
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

// File: contracts/FABndesToken_BNDESRoles.sol

pragma solidity ^0.6.0;




contract FABndesToken_BNDESRoles is Ownable {

    RBBRegistry public registry;

    address public responsibleForInitialAllocation;
    address public responsibleForDisbursement;
    address public resposibleForApproveExtraordinaryTransfers;

    event FA_ManualIntervention_RoleOrAddress(address account, uint8 eventType);

    constructor (address newRegistryAddr) public {

        registry = RBBRegistry(newRegistryAddr);

        responsibleForInitialAllocation = msg.sender;
        responsibleForDisbursement = msg.sender;
        resposibleForApproveExtraordinaryTransfers = msg.sender;

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

}

// File: contracts/FABndesToken.sol

pragma solidity ^0.6.0;











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

*/


contract FABndesToken is SpecificRBBToken {

    RBBToken public rbbToken;
    FABndesToken_BNDESRoles public bndesRoles;

    //RBBId donor => true/false (registered or not)
    mapping (uint => bool) public donors;

    //RBBId client => (idFinancialSupportAgreement Client => true/false (registered or not)
    mapping (uint => mapping (string => bool)) public clients;
    mapping (bytes32 => string) public hashToIdFinancialSupportAgreement;

    //RBBId supplier => true/false (registered or not)
    mapping (uint => bool) public suppliers;

    mapping (bytes32 => string) public accountHashMeaning;

    //Hash of approved Extraordinary Transfers
    bytes32[] public hashApprovedExtraordinaryTransfers;

    // BNDES Fee percentage
    uint256 public bndesFee;    

    //Types of transfer operation
    string public INITIAL_ALLOCATION = "INITIAL_ALLOCATION";
    string public DISBURSEMENT_VERIFICATION = "DISBURSEMENT_VERIFICATION";
    string public CLIENT_PAY_SUPPLIER_VERIFICATION = "CLIENT_PAY_SUPPLIER_VERIFICATION";
    string public BNDES_PAY_SUPPLIER_VERIFICATION = "BNDES_PAY_SUPPLIER_VERIFICATION";
    string public EXTRAORDINARY_TRANSFERS = "EXTRAORDINARY_TRANSFERS";


    uint8 public RESERVED_MINTED_ACCOUNT = 0;
    uint8 public RESERVED_USUAL_DISBURSEMENTS_ACCOUNT = 1;
    uint8 public RESERVED_BNDES_ADMIN_FEE_TO_HASH = 2;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_DONOR = 10;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER = 20;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY = 30;

    using SafeMath for uint;
   
    event FA_DonationBooked(uint idDonor, uint amount, bytes32 docHash);
    event FA_DonationConfirmed(uint idDonor, uint amount, bytes32 docHash);

    event FA_InitialAllocation_Disbursements(uint amount, bytes32 docHash);
    event FA_InitialAllocation_Fee(uint amount, bytes32 docHash);

    event FA_Disbursement  (uint idClient, string idFinancialSupportAgreement, uint amount, bytes32 docHash);
    event FA_TokenTransfer (uint fromCnpj, string fromIdFinancialSupportAgreement, uint toCnpj, uint amount, bytes32 docHash);
    event FA_BNDES_TokenTransfer(uint toCnpj, uint amount, bytes32 docHash);
    event FA_RedemptionRequested (uint idClaimer, uint amount, bytes32 docHash);
    event FA_RedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash);
 
    event FA_ExtraordinaryTransferAllowed (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);
    event FA_ExtraordinaryTransferExecuted(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);

    event FA_ManualIntervention_Fee(uint256 percent, bytes32 docHash);

    event FA_DonorAdded(uint id);
    event FA_ClientAdded(uint id);
    event FA_SupplierAdded(uint registeredBy, uint id);


    constructor (address newrbbTokenAddr, address addrBndesRoles, uint fee) public {
        require (fee < 100, "Valor de Fee maior que 100%");

        rbbToken = RBBToken(newrbbTokenAddr);
        bndesRoles = FABndesToken_BNDESRoles(addrBndesRoles);

        bndesFee = fee;
    }


    function setBNDESFee(uint256 newBndesFee, bytes32 docHash) public onlyOwner {
        require (newBndesFee < 100, "Valor de Fee maior que 100%");
        bndesFee = newBndesFee;
        emit FA_ManualIntervention_Fee(newBndesFee, docHash);
    }


    function bookDonation(uint amount, bytes32 docHash) public whenNotPaused  {        
        
        uint idDonor = registry.getId(msg.sender);

        require (donors[idDonor], "Somente doadores podem fazer doações");
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        
        bytes32 specificHash = getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY);
        rbbToken.requestMint(specificHash, idDonor, amount, docHash);

        emit FA_DonationBooked(idDonor, amount, docHash);
    }
    
    /* confirms the donor's donation */
    function verifyAndActForMint(uint idDonor, bytes32 specificHash, uint amount, bytes32 docHash,
        string[] memory data) public override whenNotPaused onlyRBBToken {

        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY)==specificHash, "Erro no cálculo do hash da doação");

        require (donors[idDonor], "Somente doadores podem fazer doações, registro estah incorreto");

        emit FA_DonationConfirmed(idDonor, amount, docHash);

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
            "Um CNPJ não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        if (!suppliers[toId]) {
            suppliers[toId] = true; //register the supplier
            emit FA_SupplierAdded(fromId, toId);
        }

        emit FA_TokenTransfer (fromId, idFinancialSupportAgreement, toId, amount, docHash);

    }


    function verifyAndActForTransfer_BNDES_PAY_SUPPLIER(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {

        require (originalSender == bndesRoles.responsibleForDisbursement(), 
            "Esta transação só pode ser executada pelo responsável pelo desembolso");

        require (fromId==registry.getId(owner()), "Somente o BNDES pode executar o pagamento");
        require (getCalculatedHash(RESERVED_BNDES_ADMIN_FEE_TO_HASH)==fromHash, "Erro no cálculo do hash da conta de admin do contrato especifico");
        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER)==toHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId, "Um BNDES não pode transferir token para si");

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

    function addDonor (uint idDonor) public onlyOwner {
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        if(!donors[idDonor]) {
            donors[idDonor] = true;
            emit FA_DonorAdded(idDonor);
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


    function addSupplier (uint id) public  {

        require (msg.sender == bndesRoles.responsibleForDisbursement(), "Esta transação só pode ser executada pelo responsável pelo desembolso");
        if (!suppliers[id]) {
            suppliers[id] = true; //register the supplier
            emit FA_SupplierAdded(registry.getId(owner()), id);
        }
    }

    function hasRoleInThisContract (uint rbbId, bytes32 hashToAccount) private view returns (bool) {

        if (donors[rbbId]==true) return true;

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
// File: contracts/RBBLib.sol

pragma solidity ^0.6.0;

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

// File: contracts/RBBRegistry.sol

pragma solidity ^0.6.0;



/*
Acho que LegalEntityInfo deveria conter id, ao invés de cnpj
No caso de pessoa jurídica, o id é o cnpj
No caso de pessoa física, um link para um cpf (por causa da LGPD).
*/

// File: @openzeppelin/contracts/access/Roles.sol

pragma solidity ^0.6.0;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */

// File: @openzeppelin/contracts/access/roles/PauserRole.sol

pragma solidity ^0.6.0;




// File: @openzeppelin/contracts/lifecycle/Pausable.sol

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

// File: contracts/SpecificRBBToken.sol

pragma solidity ^0.6.0;






// File: contracts/SpecificRBBTokenRegistry.sol

pragma solidity ^0.6.0;






// File: @openzeppelin/contracts/math/SafeMath.sol

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

// File: contracts/RBBToken.sol

pragma solidity ^0.6.0;









// File: contracts/FABndesToken_BNDESRoles.sol

pragma solidity ^0.6.0;





// File: contracts/FABndesToken.sol

pragma solidity ^0.6.0;










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

*/
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

// File: @openzeppelin/contracts/access/Roles.sol

pragma solidity ^0.6.0;

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

// File: @openzeppelin/contracts/access/roles/PauserRole.sol

pragma solidity ^0.6.0;



contract PauserRole is Context {
    using Roles for Roles.Role;

    event PauserAdded(address indexed account);
    event PauserRemoved(address indexed account);

    Roles.Role private _pausers;

    constructor () internal {
        _addPauser(_msgSender());
    }

    modifier onlyPauser() {
        require(isPauser(_msgSender()), "PauserRole: caller does not have the Pauser role");
        _;
    }

    function isPauser(address account) public view returns (bool) {
        return _pausers.has(account);
    }

    function addPauser(address account) public onlyPauser {
        _addPauser(account);
    }

    function renouncePauser() public {
        _removePauser(_msgSender());
    }

    function _addPauser(address account) internal {
        _pausers.add(account);
        emit PauserAdded(account);
    }

    function _removePauser(address account) internal {
        _pausers.remove(account);
        emit PauserRemoved(account);
    }
}

// File: @openzeppelin/contracts/lifecycle/Pausable.sol

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
contract Pausable is Context, PauserRole {
    /**
     * @dev Emitted when the pause is triggered by a pauser (`account`).
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by a pauser (`account`).
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state. Assigns the Pauser role
     * to the deployer.
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
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause() public onlyPauser whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    function unpause() public onlyPauser whenPaused {
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
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
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

//TODO: avaliar se deveria ter um set para modificar esses atributos
    SpecificRBBTokenRegistry tokenRegistry;
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

        (uint specificTokenId, uint businessContractOwnerId) = 
                    tokenRegistry.getSpecificRBBTokenIdAndOwnerId(specificTokenAddr);

        balanceRequestedTokens[specificTokenId][specificHash] 
            = balanceRequestedTokens[specificTokenId][specificHash].sub(amount, "Total de emissão excede valor solicitado");

        SpecificRBBToken specificToken = SpecificRBBToken(specificTokenAddr);

        //Retorna a conta de mint associada ao hash especifico. 
        bytes32 calcHash = specificToken.getHashToMintedAccount(specificHash);

        rbbBalances[specificTokenId][businessContractOwnerId][calcHash] = 
            rbbBalances[specificTokenId][businessContractOwnerId][calcHash].add(amount);

        specificToken.verifyAndActForMint(idInvestor, specificHash, amount, docHash, data);

        emit RBBTokenMint(specificTokenAddr, specificHash, amount, docHash, data);
    }


    function burnOwnTokenBySpecificTokens (address originalSender, bytes32 hashToBurn, uint amount, 
        bytes32 docHash) public {

        address specificTokenAddr = msg.sender;
        tokenRegistry.verifyTokenIsRegisteredAndActive(specificTokenAddr);

        (uint specificTokenId, uint businessContractOwnerId) = 
                    tokenRegistry.getSpecificRBBTokenIdAndOwnerId(specificTokenAddr);
        
        _burn(specificTokenAddr, originalSender, businessContractOwnerId, hashToBurn, amount, docHash);

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

        require(registry.isValidatedId(fromId), "Conta de origem precisa estar com cadastro validado");
        require(registry.isValidatedId(toId), "Conta de destino precisa estar com cadastro validado");
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

            require(registry.isValidatedId(fromId), "Conta solicitante do redeem precisa estar com cadastro validado");
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

// File: contracts/FABndesToken_BNDESRoles.sol

pragma solidity ^0.6.0;




contract FABndesToken_BNDESRoles is Ownable {

    RBBRegistry public registry;

    address public responsibleForInitialAllocation;
    address public responsibleForDisbursement;
    address public resposibleForApproveExtraordinaryTransfers;

    event FA_ManualIntervention_RoleOrAddress(address account, uint8 eventType);

    constructor (address newRegistryAddr) public {

        registry = RBBRegistry(newRegistryAddr);

        responsibleForInitialAllocation = msg.sender;
        responsibleForDisbursement = msg.sender;
        resposibleForApproveExtraordinaryTransfers = msg.sender;

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

}

// File: contracts/FABndesToken.sol

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

*/
contract FABndesToken is SpecificRBBToken {

    RBBToken public rbbToken;
    FABndesToken_BNDESRoles public bndesRoles;

    //RBBId donor => true/false (registered or not)
    mapping (uint => bool) public donors;

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
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_DONOR = 10;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER = 20;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY = 30;

    using SafeMath for uint;
   
    event FA_DonationBooked(uint idDonor, uint amount, bytes32 docHash);
    event FA_DonationConfirmed(uint idDonor, uint amount, bytes32 docHash);

    event FA_InitialAllocation_Disbursements(uint amount, bytes32 docHash);
    event FA_InitialAllocation_Fee(uint amount, bytes32 docHash);

    event FA_Disbursement  (uint idClient, string idFinancialSupportAgreement, uint amount, bytes32 docHash);
    event FA_TokenTransfer (uint fromCnpj, string fromIdFinancialSupportAgreement, uint toCnpj, uint amount, bytes32 docHash);
    event FA_BNDES_TokenTransfer(uint toCnpj, uint amount, bytes32 docHash);
    event FA_RedemptionRequested (uint idClaimer, uint amount, bytes32 docHash);
    event FA_RedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash);
 
    event FA_ExtraordinaryTransferAllowed (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);
    event FA_ExtraordinaryTransferExecuted(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);

//    event FA_ManualIntervention_Fee(uint256 percent, bytes32 docHash);

    event FA_DonorAdded(uint id);
    event FA_ClientAdded(uint id);
    event FA_SupplierAdded(uint registeredBy, uint id);


    constructor (address newrbbTokenAddr, address addrBndesRoles) public {
//        require (fee < 100, "Valor de Fee maior que 100%");

        rbbToken = RBBToken(newrbbTokenAddr);
        bndesRoles = FABndesToken_BNDESRoles(addrBndesRoles);

//        bndesFee = fee;
    }

/*
    function setBNDESFee(uint256 newBndesFee, bytes32 docHash) public onlyOwner {
        require (newBndesFee < 100, "Valor de Fee maior que 100%");
        bndesFee = newBndesFee;
        emit FA_ManualIntervention_Fee(newBndesFee, docHash);
    }
*/

    function bookDonation(uint amount, bytes32 docHash) public whenNotPaused  {        
        
        uint idDonor = registry.getId(msg.sender);

        require (donors[idDonor], "Somente doadores podem fazer doações");
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        
        bytes32 specificHash = getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY);
        rbbToken.requestMint(specificHash, idDonor, amount, docHash);

        emit FA_DonationBooked(idDonor, amount, docHash);
    }
    
    /* confirms the donor's donation */
    function verifyAndActForMint(uint idDonor, bytes32 specificHash, uint amount, bytes32 docHash,
        string[] memory data) public override whenNotPaused onlyRBBToken {

        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY)==specificHash, "Erro no cálculo do hash da doação");

        require (donors[idDonor], "Somente doadores podem fazer doações, registro estah incorreto");

        emit FA_DonationConfirmed(idDonor, amount, docHash);

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
            "Um CNPJ não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        if (!suppliers[toId]) {
            suppliers[toId] = true; //register the supplier
            emit FA_SupplierAdded(fromId, toId);
        }

        emit FA_TokenTransfer (fromId, idFinancialSupportAgreement, toId, amount, docHash);

    }


    function verifyAndActForTransfer_BNDES_PAY_SUPPLIER(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {

        require (originalSender == bndesRoles.responsibleForDisbursement(), 
            "Esta transação só pode ser executada pelo responsável pelo desembolso");

        require (fromId==registry.getId(owner()), "Somente o BNDES pode executar o pagamento");
        require (getCalculatedHash(RESERVED_BNDES_ADMIN_FEE_TO_HASH)==fromHash, "Erro no cálculo do hash da conta de admin do contrato especifico");
        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER)==toHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId, "Um BNDES não pode transferir token para si");

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

    function addDonor (uint idDonor) public onlyOwner {
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        if(!donors[idDonor]) {
            donors[idDonor] = true;
            emit FA_DonorAdded(idDonor);
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


    function addSupplier (uint id) public  {

        require (msg.sender == bndesRoles.responsibleForDisbursement(), "Esta transação só pode ser executada pelo responsável pelo desembolso");
        if (!suppliers[id]) {
            suppliers[id] = true; //register the supplier
            emit FA_SupplierAdded(registry.getId(owner()), id);
        }
    }

    function hasRoleInThisContract (uint rbbId, bytes32 hashToAccount) private view returns (bool) {

        if (donors[rbbId]==true) return true;

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

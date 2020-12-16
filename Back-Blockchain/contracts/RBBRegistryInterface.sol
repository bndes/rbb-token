pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RBBLib.sol";
import "./RBBRegistry.sol";

interface RBBRegistryInterface{

function registryLegalEntity(uint CNPJ, bytes32 CNPJProofHash) external;
    function validateRegistrySameOrg(address userAddr) external  ;
    function validateRegistry(address userAddr) external ;
    function pauseAddress(address addr) external ;
    function pauseLegalEntity(uint RBBId) external ;
    function unpauseAddress(address addr) external ; 
    function invalidateRegistry(address addr) external ; 
    function isSortOfAdmin(address addr) external view  returns (bool);

    function isOwner(address addr) external view  returns (bool) ;

    function isAvailableAccount(address addr) external view  returns (bool); 

    function isWaitingValidationAccount(address addr) external view returns (bool);

    function isValidatedAccount(address addr) external view  returns (bool) ;

    function isInvalidated(address addr) external view  returns (bool) ;

    function isTheSameID(address a, address b) external view  returns (bool); 

    function isPaused(address addr) external view  returns (bool) ;

    function isOperational(address addr) external view  returns (bool); 

    function isRegistryOperational(uint RBBId) external view  returns (bool); 

    function getId (address addr) external view  returns (uint) ;

    function getRBBIdRaw (address addr) external view  returns (uint); 

    function getCNPJ (address addr) external view  returns (uint)  ;

     function getRegistry (address addr) external view  returns (uint, uint, bytes32, uint, uint, bool, uint256); 

    function getBlockchainAccounts(uint RBBId) external view  returns (address[] memory) ;

    function getAccountState(address addr) external view  returns (int) ;

    function getAccountRole(address addr) external view  returns (int) ;

    function getIdFromCNPJ(uint cnpj) external view  returns (uint); 
    function setRoleSupAdmin(address addr) external  ;
    function setDefaultDateTimeExpiration(uint256 dateTimeExpirationNew) external ;

    
    function getCNPJbyID(uint Id) external view  returns (uint );
    

 

}

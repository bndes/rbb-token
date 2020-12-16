pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RBBLib.sol";
import "./RBBRegistry.sol";

interface RBBRegistryInterface{

    function isRegistryOperational(uint RBBId) external view  returns (bool); 

    function getRegistry (address addr) external view  returns (uint, uint, bytes32, uint, uint, bool, uint256); 

    function getIdFromCNPJ(uint cnpj) external view  returns (uint); 
  
    function getCNPJbyID(uint Id) external view  returns (uint );


}

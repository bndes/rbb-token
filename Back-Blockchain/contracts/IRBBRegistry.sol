pragma solidity ^0.6.0;

interface IRBBRegistry {

    //Verifica se estah operacional antes de retornar
    function getId (address addr) external view returns (uint);

    //retorna toda estrutura. Não verifica se estah operacional
    function getRegistry (address addr) external view  returns (uint, uint, bytes32, uint, uint, bool, uint256); 

    //Não verifica se estah operacional antes de retornar
    function getIdFromCNPJ(uint cnpj) external view  returns (uint); 
  
    //Não verifica se estah operacional antes de retornar
    function getCNPJbyID(uint Id) external view  returns (uint);

    function isRegistryOperational(uint RBBId) external view  returns (bool); 


}

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RBBRegistry.sol";
import "./SpecificRBBToken.sol";


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

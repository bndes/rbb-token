pragma solidity ^0.6.0;

import "./RBBRegistry.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";


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
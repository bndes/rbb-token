pragma solidity ^0.5.0;

import "@openzeppelin/contracts/access/Roles.sol";


//TODO: validacao serah por id RBB (e nao por conta)
contract RegistryValidatorRegistry {

/*
    using Roles for Roles.Role;

    event RegistryValidatorAdded(address indexed account);
    event RegistryValidatorRemoved(address indexed account);

    Roles.Role private _registryValidators;

    constructor () internal {
        _addRegistryValidator(msg.sender);
    }

    modifier onlyRegistryValidator() {
        require(isRegistryValidator(msg.sender));
        _;
    }

    function isRegistryValidator(address account) public view returns (bool) {
        return _registryValidators.has(account);
    }

    function addRegistryValidator(address account) public onlyRegistryValidator {
        _addRegistryValidator(account);
    }

    function renounceRegistryValidator() public {
        _removeRegistryValidator(msg.sender);
    }

    function _addRegistryValidator(address account) internal {
        _registryValidators.add(account);
        emit RegistryValidatorAdded(account);
    }

    function _removeRegistryValidator(address account) internal {
        _registryValidators.remove(account);
        emit RegistryValidatorRemoved(account);
    }
    */
}
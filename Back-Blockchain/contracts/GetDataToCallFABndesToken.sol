pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./FABndesToken.sol";


contract GetDataToCallFABndesToken  {

    FABndesToken faBndesToken;

    constructor (address addr) public {
        faBndesToken = FABndesToken(addr);
    }

    function getInitialAllocationToDisbusementData () public view
        returns (bytes32, bytes32, string[] memory)  {

        bytes32 fromHash = getCalculatedHash(faBndesToken.RESERVED_MINTED_ACCOUNT());
        bytes32 toHash = getCalculatedHash(faBndesToken.RESERVED_USUAL_DISBURSEMENTS_ACCOUNT());

        string[] memory data = new string[](1);
        data[0] = faBndesToken.INITIAL_ALLOCATION();
        return (fromHash, toHash, data);
    }

    function getInitialAllocationToChargeFeeData () public view
        returns (bytes32, bytes32, string[] memory)  {

        bytes32 fromHash = getCalculatedHash(faBndesToken.RESERVED_MINTED_ACCOUNT());
        bytes32 toHash = getCalculatedHash(faBndesToken.RESERVED_BNDES_ADMIN_FEE_TO_HASH());

        string[] memory data = new string[](1);
        data[0] = faBndesToken.INITIAL_ALLOCATION();
        return (fromHash, toHash, data);
    }

    function getDisbusementData (string memory idFinancialSupportAgreement) public view
        returns (bytes32, bytes32, string[] memory)  {

        bytes32 fromHash = getCalculatedHash(faBndesToken.RESERVED_USUAL_DISBURSEMENTS_ACCOUNT());
        bytes32 toHash = getCalculatedHash(idFinancialSupportAgreement);

        string[] memory data = new string[](2);
        data[0] = faBndesToken.DISBURSEMENT_VERIFICATION();
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

    function getClientPaySupplierData (string memory idFinancialSupportAgreement) public view
            returns (bytes32, bytes32, string[] memory) {

        bytes32 fromHash = getCalculatedHash(idFinancialSupportAgreement);
        bytes32 toHash = getCalculatedHash(faBndesToken.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER());

        string[] memory data = new string[](2);
        data[0] = faBndesToken.CLIENT_PAY_SUPPLIER_VERIFICATION();
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

    function getBNDESPaySupplierData () public view
            returns (bytes32, bytes32, string[] memory) {

        bytes32 fromHash = getCalculatedHash(faBndesToken.RESERVED_USUAL_DISBURSEMENTS_ACCOUNT());
        bytes32 toHash = getCalculatedHash(faBndesToken.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER());

        string[] memory data = new string[](1);
        data[0] = faBndesToken.BNDES_PAY_SUPPLIER_VERIFICATION();
        return (fromHash, toHash, data);
    }

    function getRedeemData () public 
            returns (bytes32, string[] memory) {

        bytes32 fromHash = getCalculatedHash(faBndesToken.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER());

        string[] memory data = new string[](0);
        return (fromHash, data);
    }

    function getCalculatedHash (uint info) public view returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }
    function getCalculatedHash (string memory info) public view returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }


}



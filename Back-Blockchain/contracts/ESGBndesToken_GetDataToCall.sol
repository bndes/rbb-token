pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./ESGBndesToken.sol";


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



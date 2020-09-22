pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./RBBToken.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

abstract contract SpecificRBBToken is Ownable, Pausable {

    RBBRegistry public registry;
    RBBToken public rbbToken;

    constructor () public {
    }

    function setInitializationDataDuringRegistration(address newRegistryAddr, address newrbbTokenAddr) public {
        registry = RBBRegistry(newRegistryAddr);
        rbbToken = RBBToken(newrbbTokenAddr);
    }

//TODO: acrescenar receiptHash
    function verifyAndActForMint(bytes32 specificHash, uint amount, string[] memory data,
        string memory docHash) virtual public;

    function verifyAndActForTransfer(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) virtual public;

    function verifyAndActForRedeem(uint fromId, bytes32 fromHash, uint amount, string[] memory data) virtual public;
    
    
    function verifyAndActForRedemptionSettlement(string memory redemptionTransactionHash, string memory receiptHash, 
        string[] memory data) virtual public;

}

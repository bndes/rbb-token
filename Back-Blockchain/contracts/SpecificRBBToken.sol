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

    function getHashToMintedAccount(bytes32 specificHash) virtual public returns (bytes32);

    function verifyAndActForMint(bytes32 specificHash, uint amount, bytes32 docHash, 
            string[] memory data) virtual public;

    function verifyAndActForTransfer(address originalSender, uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash, string[] memory data) virtual public;

    function verifyAndActForRedeem(address originalSender, uint fromId, bytes32 fromHash, uint amount, bytes32 docHash, 
            string[] memory data) virtual public;
    
    function verifyAndActForRedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash, 
        string[] memory data) virtual public;

}

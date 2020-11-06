pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

abstract contract SpecificRBBToken is Ownable, Pausable {

    RBBRegistry public registry;

    constructor () public {
    }

    function setInitializationDataDuringRegistration(address newRegistryAddr) public {
        registry = RBBRegistry(newRegistryAddr);
    }

    function getHashToMintedAccount(bytes32 specificHash) virtual public returns (bytes32);

    function verifyAndActForMint(uint idInvestor, bytes32 specificHash, uint amount, bytes32 docHash, 
            string[] memory data) virtual public;

    function verifyAndActForTransfer(address originalSender, uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash, string[] memory data) virtual public;

    function verifyAndActForRedeem(address originalSender, uint fromId, bytes32 fromHash, uint amount, bytes32 docHash, 
            string[] memory data) virtual public;
    
    function verifyAndActForRedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash, 
        string[] memory data) virtual public;


}

pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./RBBToken.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

contract SpecificRBBToken is Ownable, Pausable {

    RBBRegistry public registry;
    RBBToken public rbbToken;

    constructor (address newRegistryAddr, address newrbbTokenAddr) public {

        registry = RBBRegistry(newRegistryAddr);
        rbbToken = RBBToken(newrbbTokenAddr);

    }


    function verifyAndActForTransfer(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public;


    function verifyAndActForRedeem(uint fromId, bytes32 fromHash, uint amount, string[] memory data) public;
    

}

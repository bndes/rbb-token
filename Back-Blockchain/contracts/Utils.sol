
pragma solidity ^0.5.0;

library RBBLib {

  function isValidHash(string memory str) public pure returns (bool)  {

    bytes memory b = bytes(str);
    if(b.length != 64) return false;

    for (uint i = 0; i < 64; i++) {
        if (b[i] < "0") return false;
        if (b[i] > "9" && b[i] < "a") return false;
        if (b[i] > "f") return false;
    }

    return true;
  }

}
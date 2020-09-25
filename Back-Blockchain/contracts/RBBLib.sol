
pragma solidity ^0.6.0;

library RBBLib {

  function isEqual(string memory a, string memory b) public pure returns (bool) {
    bool r = keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    return r;
  }

  function bytesToBytes32(bytes memory _bytes) private pure returns (bytes32) {
        bytes32 out;
        uint _len= _bytes.length;
        if(_len>32){
            _len = 32;
        }
        for (uint i = 0; i < _len; i++) {
            out |= bytes32(_bytes[i]) >> (i * 8);
        }
        return out;
  }

  function stringBytes32(string memory _String ) pure public returns(bytes32  ){
        bytes memory _bytes = bytes(_String);
              
        return bytesToBytes32(_bytes);
       // bytes memory b = abi.encodePacked(a);
       
  } 


  function uintToStr(uint _i) public pure returns (string memory ) {
        uint number = _i;
        if (number == 0) {
            return "0";
        }
        uint j = number;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (number != 0) {
            bstr[k--] = byte(uint8(48 + number % 10));
            number /= 10;
        }
        return string(bstr);
  }
    
  function bytes32ToStr(bytes32 _bytes32) public pure returns (string memory) {


    bytes memory compare = new bytes(32);
    //bytes memory bytesArray = new bytes(32);
    bytes memory bytesArray = new bytes(1);
    string memory stringOut;
    for (uint256 i; i < 32; i++) {
        bytesArray[0] = _bytes32[i];
        if(bytesArray[0] != compare[i]){
            stringOut = string(abi.encodePacked(stringOut,string(bytesArray)));
            
        }
    }
    
    
    return stringOut;
    //return string(bytesArray);
    }


  function stringtoUint(string memory _string) pure public returns(uint256){
       uint256 outNumber;
       uint256 number;
       bytes memory b =bytes(_string);
        for(uint i=0;i<b.length;i++){
            outNumber = outNumber*10;
            number = (uint256(uint8(b[i])));
           // return number;
            require(number  > 47  && number < 58, "essa string não é um numero");
            number = number -48;
            outNumber = outNumber + number;
        }
       return outNumber;
   }



    

}
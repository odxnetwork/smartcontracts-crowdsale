pragma solidity ^0.4.23;

import "./ODXPrivateSale.sol";

contract MockODXPrivateSale is ODXPrivateSale {
  function turnBackTime(uint256 secs) external {
    for (uint i=0; i<lockupTimes.length; i++) {
        uint256 lockupTime = lockupTimes[i];
        lockupTimes[i] = lockupTime - secs;
    }
  }
    
  constructor(
    ODXToken _token
  )
    public
    ODXPrivateSale(_token)
  {  }
}
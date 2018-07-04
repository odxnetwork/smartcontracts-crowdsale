pragma solidity ^0.4.23;

import "./PrivateSaleRules.sol";
import "./ODXToken.sol";

/**
 * @title ODXPrivateSale
 * @dev This is for the private sale of ODX.  
 */
contract ODXPrivateSale is PrivateSaleRules {

  uint256[] alockupTimes = [now + 10 minutes, now + 15 minutes, now + 20 minutes];
  
  constructor(
    ODXToken _token
  )
    public
    PrivateSaleRules(alockupTimes, _token)
  {  }
  
}

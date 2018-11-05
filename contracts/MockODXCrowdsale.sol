pragma solidity ^0.4.23;

import "./ODXCrowdsale.sol";

contract MockODXCrowdsale is ODXCrowdsale {
    function turnBackTime(uint256 secs) external {
        openingTime -= secs;
        closingTime -= secs;
    }
    
  constructor(
    uint256 _rate,
    address _wallet,
    uint256 _cap,
    uint256 _tokenCap,
    ODXToken _token,
    uint256 _minContribution,
    uint256 _openingTime
  )
    public
    ODXCrowdsale(_rate, _wallet, _cap, _tokenCap, _token, _minContribution, _openingTime)
  {
  }
}	
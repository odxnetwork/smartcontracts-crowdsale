pragma solidity ^0.4.23;

import "./CrowdsaleNewRules.sol";
import "./ODXToken.sol";

/**
 * @title ODXCrowdsale
 * @dev This is a crowdsale that is capped, timed, token are delivered after the crowdsale to all whitelisted addresses (kyc)
 * crowdsale will run for xx days.
 * Added minimum contribution.
 */
contract ODXCrowdsale is CrowdsaleNewRules {
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
    Crowdsale(_rate, _wallet, _token)
    CappedCrowdsale(_cap, _tokenCap)
    CrowdsaleNewRules(_minContribution)
    TimedCrowdsale(_openingTime, now + 1 hours)
    //TimedCrowdsale(now, now + 1 hours)
    CrowdsaleFromOtherSource()
  {
    require(_rate > 0);
  }
  
}

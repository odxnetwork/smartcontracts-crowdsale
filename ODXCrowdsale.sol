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
    uint256 _goal,
    uint256 _minContribution,
    uint256 _openingTime
  )
    public
    Crowdsale(_rate, _wallet, _token)
    CappedCrowdsale(_cap, _tokenCap)
    CrowdsaleNewRules(_minContribution, _goal)
    TimedCrowdsale(_openingTime, now + 30 days)
  {
    //As goal needs to be met for a successful crowdsale
    //the value needs to less or equal than a cap which is limit for accepted funds
    require(_goal <= _cap);
    require(_rate > 0);
  }
  
}

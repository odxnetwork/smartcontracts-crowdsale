pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "./Crowdsale.sol";


/**
 * @title CappedCrowdsale
 * @dev Crowdsale with a limit for total contributions.
 * And limits the number of tokens to be minted for the crowdsale
 */
contract CappedCrowdsale is Crowdsale {
  using SafeMath for uint256;

  uint256 public cap;
  uint256 public tokenCap;

  /**
   * @dev Constructor, takes maximum amount of wei accepted in the crowdsale.
   * @param _cap Max amount of wei to be contributed
   */
  constructor(uint256 _cap, uint256 _tokenCap) public {
    require(_cap > 0);
    require(_tokenCap > 0);
    cap = _cap;
    tokenCap = _tokenCap;
  }
  

  /**
   * @dev Checks whether the cap has been reached. 
   * @return Whether the cap was reached
   */
  function capReached() public view returns (bool) {
    return weiRaised >= cap;
  }

  /**
   * @dev Checks whether the token cap has been reached. 
   * @return Whether the token cap was reached
   */
  function tokenCapReached() public view returns (bool) {
    return tokensToBeMinted >= tokenCap;
  }

}

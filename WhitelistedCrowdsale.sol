pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "./Crowdsale.sol";
import "./Ownable.sol";


/**
 * @title WhitelistedCrowdsale
 * @dev Crowdsale that whitelists investors.
 */
contract WhitelistedCrowdsale is Crowdsale, Ownable {
  using SafeMath for uint256;

  mapping(address => bool) public whitelist;
  
  mapping (address => bool) public whitelistAgents;
  
  event WhitelistAgentChanged(address addr, bool state);
  
  
  modifier onlyWhitelistAgent() {
    // crowdsale contracts or owner are allowed to whitelist address
    if(!whitelistAgents[msg.sender] && (msg.sender != owner)) {
        revert();
    }
    _;
  }
  
  /**
   * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
   */
  modifier isWhitelisted(address _beneficiary) {
    require(whitelist[_beneficiary]);
    _;
  }

  /**
   * Owner can add an address to the whitelistagents.
   */
  function setWhitelistAgent(address addr, bool state) onlyOwner public {
    whitelistAgents[addr] = state;
    emit WhitelistAgentChanged(addr, state);
  }
  
}

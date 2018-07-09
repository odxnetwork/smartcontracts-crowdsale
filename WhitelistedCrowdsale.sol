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
  
  
  /**
   * @dev Adds single address to whitelist.
   * @param _beneficiary Address to be added to the whitelist
   */
  function addToWhitelist(address _beneficiary) external onlyWhitelistAgent {
    whitelist[_beneficiary] = true;
  }

  /**
   * @dev Adds list of addresses to whitelist. Not overloaded due to limitations with truffle testing.
   * @param _beneficiaries Addresses to be added to the whitelist
   */
  function addManyToWhitelist(address[] _beneficiaries) external onlyWhitelistAgent {
    for (uint256 i = 0; i < _beneficiaries.length; i++) {
      whitelist[_beneficiaries[i]] = true;
    }
  }

  /**
   * @dev Removes single address from whitelist.
   * @param _beneficiary Address to be removed to the whitelist
   */
  function removeFromWhitelist(address _beneficiary) external onlyWhitelistAgent {
    whitelist[_beneficiary] = false;
  }

}

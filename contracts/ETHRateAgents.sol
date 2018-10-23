pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "./Ownable.sol";


/**
 * @title ETHRateAgents
 * @dev set addresses that can call the update rate function
 */
contract ETHRateAgents is Ownable {
  using SafeMath for uint256;

  mapping (address => bool) public ethRateAgents;
  
  event ETHRateAgentChanged(address addr, bool state);
  
  modifier onlyETHRateAgent() {
    // crowdsale contracts or owner are allowed to update eth rate
    if(!ethRateAgents[msg.sender] && (msg.sender != owner)) {
        revert();
    }
    _;
  }
  
  /**
   * Owner can add an address to the ethRateAgents.
   */
  function setETHRateAgent(address addr, bool state) onlyOwner public {
    ethRateAgents[addr] = state;
    emit ETHRateAgentChanged(addr, state);
  }
  
}

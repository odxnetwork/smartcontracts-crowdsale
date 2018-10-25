pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "./Crowdsale.sol";
import "./Ownable.sol";


/**
 * @title CrowdsaleFromOtherSource
 * @dev Crowdsale that accepts contribution from other sources/coins.
 */
contract CrowdsaleFromOtherSource is Crowdsale, Ownable {
  using SafeMath for uint256;

  mapping (address => bool) public allowedAgentsForOtherSource;
  
  mapping(string => uint256) raisedAmount;
  
  event AllowedAgentsForOtherSourceChanged(address addr, bool state);
  
  modifier onlyAllowedAgentForOtherSource() {
    // crowdsale contracts or owner are allowed to whitelist address
    if(!allowedAgentsForOtherSource[msg.sender] && (msg.sender != owner)) {
        revert();
    }
    _;
  }
  
  constructor() public {
  }
  
  /**
   * Owner can add an address to the whitelistagents.
   */
  function setAllowedAgentsForOtherSource(address addr, bool state) onlyOwner public {
    allowedAgentsForOtherSource[addr] = state;
    emit AllowedAgentsForOtherSourceChanged(addr, state);
  }
  
  function validOtherSource(string _newOtherSource) internal view returns (bool) {
    if (keccak256(_newOtherSource)==keccak256("BTC") || keccak256(_newOtherSource)==keccak256("LTC")) return true;
    return false;
  }
  
  function getRaisedAmount(string source) public view returns (uint256){
      return raisedAmount[source];
  }
  
}

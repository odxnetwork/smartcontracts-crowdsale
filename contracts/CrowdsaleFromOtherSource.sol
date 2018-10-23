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
  
  mapping(bytes32 => uint256) public raisedAmount;
  
  bytes32[] public allowedOtherSource;
  
  event AllowedAgentsForOtherSourceChanged(address addr, bool state);
  event AddAllowedOtherSource(bytes32 otherSource);
  event RemoveAllowedOtherSource(bytes32 otherSource);
  
  modifier onlyAllowedAgentForOtherSource() {
    // crowdsale contracts or owner are allowed to whitelist address
    if(!allowedAgentsForOtherSource[msg.sender] && (msg.sender != owner)) {
        revert();
    }
    _;
  }
  
  /**
   * @dev Constructor, takes the initial allowed other source/coins.
   * @param _allowedOtherSource initial other source/coins allowed
   */
  constructor(bytes32[] _allowedOtherSource) public {
    allowedOtherSource = _allowedOtherSource;
  }
  
  /**
   * Owner can add an address to the whitelistagents.
   */
  function setAllowedAgentsForOtherSource(address addr, bool state) onlyOwner public {
    allowedAgentsForOtherSource[addr] = state;
    emit AllowedAgentsForOtherSourceChanged(addr, state);
  }
  
  function otherSourceExists(bytes32 _newOtherSource) internal view returns (bool) {
    for (uint i=0; i<allowedOtherSource.length; i++) {
        if (allowedOtherSource[i] == _newOtherSource){
            return true;
        }
    }
    return false;
  }
  
  
  /**
   * @dev Adds single address to whitelist.
   * @param _newOtherSource other source to be added
   */
  function addAllowedOtherSource(bytes32 _newOtherSource) external onlyAllowedAgentForOtherSource {
    require(!otherSourceExists(_newOtherSource));
    allowedOtherSource.push(_newOtherSource);
    emit AddAllowedOtherSource(_newOtherSource);
  }


  /**
   * @dev Removes single address from whitelist.
   * @param _otherSource other source to be removed
   */
  function removeAllowedOtherSource(bytes32 _otherSource) external onlyAllowedAgentForOtherSource {
    for (uint i=0; i<allowedOtherSource.length; i++) {
        if (allowedOtherSource[i] == _otherSource){
            allowedOtherSource[i] = allowedOtherSource[allowedOtherSource.length];
            allowedOtherSource.length--;
            emit RemoveAllowedOtherSource(_otherSource);
        }
    }
  }

}

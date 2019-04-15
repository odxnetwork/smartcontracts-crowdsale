pragma solidity ^0.4.23;

import "../../token/contracts/ODXToken.sol";
import "../../token/contracts/Ownable.sol";
import "../../token/contracts/ERC20.sol";
import "../../token/contracts/SafeMath.sol";

/**
 * @title PrivateSaleRules
 * @dev Specifically use for private sale with lockup.
 */
contract PrivateSaleRules is Ownable {
  using SafeMath for uint256;

  // private sale tracker of contribution
  uint256 public weiRaisedDuringPrivateSale;

  mapping(address => uint256[]) public lockedTokens;
  
  uint256[] public lockupTimes;
  mapping(address => uint256) public privateSale;
  
  mapping (address => bool) public privateSaleAgents;

  // The token being sold
  ERC20 public token;

  event AddLockedTokens(address indexed beneficiary, uint256 totalContributionAmount, uint256[] tokenAmount);
  event UpdateLockedTokens(address indexed beneficiary, uint256 totalContributionAmount, uint256 lockedTimeIndex, uint256 tokenAmount);
  event PrivateSaleAgentChanged(address addr, bool state);


  modifier onlyPrivateSaleAgent() {
    // crowdsale contracts or owner are allowed to whitelist address
    require(privateSaleAgents[msg.sender] || msg.sender == owner);
    _;
  }
  

  /**
   * @dev Constructor, sets lockupTimes and token address
   * @param _lockupTimes arraylist of lockup times
   * @param _token tokens to be minted
   */
  constructor(uint256[] _lockupTimes, ODXToken _token) public {
    require(_lockupTimes.length > 0);
    
    lockupTimes = _lockupTimes;
    token = _token;
  }

  /**
   * Owner can add an address to the privatesaleagents.
   */
  function setPrivateSaleAgent(address addr, bool state) onlyOwner public {
    privateSaleAgents[addr] = state;
    emit PrivateSaleAgentChanged(addr, state);
  }
  
  /**
   * @dev Overrides delivery by minting tokens upon purchase.
   * @param _beneficiary Token purchaser
   * @param _tokenAmount Number of tokens to be minted
   */
  function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
    require(ODXToken(token).mint(_beneficiary, _tokenAmount));
  }
  
  /**
   * @dev claim locked tokens only after lockup time.
   */
   
  function claimLockedTokens() public {
    for (uint i=0; i<lockupTimes.length; i++) {
        uint256 lockupTime = lockupTimes[i];
        if (lockupTime < now){
            uint256 tokens = lockedTokens[msg.sender][i];
            if (tokens>0){
                lockedTokens[msg.sender][i] = 0;
                _deliverTokens(msg.sender, tokens);    
            }
        }
    }
  }


  /**
   * @dev release locked tokens only after lockup time.
   */
  function releaseLockedTokensByIndex(address _beneficiary, uint256 _lockedTimeIndex) onlyOwner public {
    require(lockupTimes[_lockedTimeIndex] < now);
    uint256 tokens = lockedTokens[_beneficiary][_lockedTimeIndex];
    if (tokens>0){
        lockedTokens[_beneficiary][_lockedTimeIndex] = 0;
        _deliverTokens(_beneficiary, tokens);    
    }
  }
  
  function releaseLockedTokens(address _beneficiary) public {
    for (uint i=0; i<lockupTimes.length; i++) {
        uint256 lockupTime = lockupTimes[i];
        if (lockupTime < now){
            uint256 tokens = lockedTokens[_beneficiary][i];
            if (tokens>0){
                lockedTokens[_beneficiary][i] = 0;
                _deliverTokens(_beneficiary, tokens);    
            }
        }
    }
    
  }
  
  function tokensReadyForRelease(uint256 releaseBatch) public view returns (bool) {
      bool forRelease = false;
      uint256 lockupTime = lockupTimes[releaseBatch];
      if (lockupTime < now){
        forRelease = true;
      }
      return forRelease;
  }

  /**
   * @dev Returns the locked tokens of a specific user.
   * @param _beneficiary Address whose locked tokens is to be checked
   * @return locked tokens for individual user
   */
  function getTotalLockedTokensPerUser(address _beneficiary) public view returns (uint256) {
    uint256 totalTokens = 0;
    uint256[] memory lTokens = lockedTokens[_beneficiary];
    for (uint i=0; i<lockupTimes.length; i++) {
        totalTokens += lTokens[i];
    }
    return totalTokens;
  }
  
  function getLockedTokensPerUser(address _beneficiary) public view returns (uint256[]) {
    return lockedTokens[_beneficiary];
  }

  function addPrivateSaleWithMonthlyLockup(address _beneficiary, uint256[] _atokenAmount, uint256 _totalContributionAmount) onlyPrivateSaleAgent public {
      require(_beneficiary != address(0));
      require(_totalContributionAmount > 0);
      require(_atokenAmount.length == lockupTimes.length);
      
      uint256 existingContribution = privateSale[_beneficiary];
      if (existingContribution > 0){
        revert();
      }else{
        lockedTokens[_beneficiary] = _atokenAmount;
        privateSale[_beneficiary] = _totalContributionAmount;
          
        weiRaisedDuringPrivateSale = weiRaisedDuringPrivateSale.add(_totalContributionAmount);
          
        emit AddLockedTokens(
          _beneficiary,
          _totalContributionAmount,
          _atokenAmount
        );
          
      }
      
  }
  
  /*
  function getTotalTokensPerArray(uint256[] _tokensArray) internal pure returns (uint256) {
      uint256 totalTokensPerArray = 0;
      for (uint i=0; i<_tokensArray.length; i++) {
        totalTokensPerArray += _tokensArray[i];
      }
      return totalTokensPerArray;
  }
  */


  /**
   * @dev update locked tokens per user 
   * @param _beneficiary Token purchaser
   * @param _lockedTimeIndex lockupTimes index
   * @param _atokenAmount Amount of tokens to be minted
   * @param _totalContributionAmount ETH equivalent of the contribution
   */
  function updatePrivateSaleWithMonthlyLockupByIndex(address _beneficiary, uint _lockedTimeIndex, uint256 _atokenAmount, uint256 _totalContributionAmount) onlyPrivateSaleAgent public {
      require(_beneficiary != address(0));
      require(_totalContributionAmount > 0);
      //_lockedTimeIndex must be valid within the lockuptimes length
      require(_lockedTimeIndex < lockupTimes.length);

      
      uint256 oldContributions = privateSale[_beneficiary];
      //make sure beneficiary has existing contribution otherwise use addPrivateSaleWithMonthlyLockup
      require(oldContributions > 0);

      //make sure lockuptime of the index is less than now (tokens were not yet released)
      require(!tokensReadyForRelease(_lockedTimeIndex));
      
      lockedTokens[_beneficiary][_lockedTimeIndex] = _atokenAmount;
      
      //subtract old contribution from weiRaisedDuringPrivateSale
      weiRaisedDuringPrivateSale = weiRaisedDuringPrivateSale.sub(oldContributions);
      
      //add new contribution to weiRaisedDuringPrivateSale
      privateSale[_beneficiary] = _totalContributionAmount;
      weiRaisedDuringPrivateSale = weiRaisedDuringPrivateSale.add(_totalContributionAmount);
            
      emit UpdateLockedTokens(
      _beneficiary,
      _totalContributionAmount,
      _lockedTimeIndex,
      _atokenAmount
    );
  }


}

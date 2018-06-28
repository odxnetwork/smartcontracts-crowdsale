pragma solidity ^0.4.23;

import "./TimedCrowdsale.sol";
import "./CappedCrowdsale.sol";
import "./ODXToken.sol";
import "./Ownable.sol";
import "./ERC20.sol";
import "./SafeMath.sol";

/**
 * @title CrowdsaleRules
 * @dev Crowdsale that locks tokens from withdrawal until it ends and makes sure that only whitelisted address can withdraw tokens.
 * Tokens are minted every withdrawal/sendtoken function.
 * gives bonus tokens to early investors
 * 061118 - removed presale
 * 061218 - required whitelisting before accepting funds
 * 061418 - removed use of vault
 */
contract CrowdsaleNewRules is CappedCrowdsale, TimedCrowdsale, Ownable {
  using SafeMath for uint256;

  mapping(address => uint256) public balances;
  mapping(address => bool) public whitelist;
  
  mapping(address => uint256[]) public lockedTokens;
  //address[] public lockupAddresses;
  uint256[] public lockupTimes;
  mapping(address => uint256) public privateSale;
  
  
  // minimum amount of funds to be raised in weis
  uint256 public goal;

  // minimum contribution
  uint256 public minContribution;
  
  // private sale tracker of contribution
  uint256 public weiRaisedDuringPrivateSale;

  event AllocateBonusTokens(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event ClearTokensAfterRefund(address indexed beneficiary, uint256 value);
  event DeliverTokens(address indexed sender, address indexed beneficiary, uint256 value);
  event AddLockedTokens(address indexed beneficiary, uint256 value, uint256[] amount);
  event UpdateLockedTokens(address indexed beneficiary, uint256 value, uint256[] amount);
  

  /**
   * @dev Constructor, sets goal, additionalTokenMultiplier and minContribution
   * @param _goal Funding goal
   */
  constructor(uint256 _minContribution, uint256 _goal, uint256[] _lockupTimes) public {
    require(_goal > 0);
    require(_minContribution > 0);
    require(_lockupTimes.length > 0);
    
    goal = _goal;
    minContribution = _minContribution;
    lockupTimes = _lockupTimes;
  }

  /**
   * @dev Reverts if beneficiary is not whitelisted. Can be used when extending this contract.
   */
  modifier isWhitelisted(address _beneficiary) {
    require(whitelist[_beneficiary]);
    _;
  }

  /**
   * @dev Adds single address to whitelist.
   * @param _beneficiary Address to be added to the whitelist
   */
  function addToWhitelist(address _beneficiary) external onlyOwner {
    whitelist[_beneficiary] = true;
  }

  /**
   * @dev Adds list of addresses to whitelist. Not overloaded due to limitations with truffle testing.
   * @param _beneficiaries Addresses to be added to the whitelist
   */
  function addManyToWhitelist(address[] _beneficiaries) external onlyOwner {
    for (uint256 i = 0; i < _beneficiaries.length; i++) {
      whitelist[_beneficiaries[i]] = true;
    }
  }

  /**
   * @dev Removes single address from whitelist.
   * @param _beneficiary Address to be removed to the whitelist
   */
  function removeFromWhitelist(address _beneficiary) external onlyOwner {
    whitelist[_beneficiary] = false;
  }

  /**
   * @dev investors can get their tokens using this method.
   */
  function withdrawTokensByInvestors() external isWhitelisted(msg.sender) {
    _sendTokens(msg.sender);
  }

  /**
   * @dev used by owner to send tokens to investors, calls the sendtokens function
   */
  function sendTokensToInvestors(address _beneficiary) external onlyOwner isWhitelisted(_beneficiary) {
    _sendTokens(_beneficiary);
  }

  /**
   * @dev Withdraw tokens only after crowdsale ends and only if the goal is reached.
   */
  function _sendTokens(address _beneficiary) internal {
    require(hasClosed());
    require(goalReached());
    uint256 amount = balances[_beneficiary];
    require(amount > 0);
    balances[_beneficiary] = 0;
    _deliverTokens(_beneficiary, amount);
    
    emit DeliverTokens(
        msg.sender,
        _beneficiary,
        amount
    );
  }
  
  /**
   * @dev Overrides parent by storing balances instead of issuing tokens right away and adds bonus tokens if applicable.
   * @param _beneficiary Token purchaser
   * @param _tokenAmount Amount of tokens purchased
   */
  function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
    balances[_beneficiary] = balances[_beneficiary].add(_tokenAmount);
  }
  
  /**
   * @dev Overrides delivery by minting tokens upon purchase.
   * @param _beneficiary Token purchaser
   * @param _tokenAmount Number of tokens to be minted
   */
  function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
    require(ODXToken(token).mint(_beneficiary, _tokenAmount));
    tokensToBeMinted = tokensToBeMinted.sub(_tokenAmount);
    //require(MintableToken(token).mint(wallet, _tokenAmount));
  }
  
  /**
   * @dev Checks whether funding goal was reached.
   * @return Whether funding goal was reached
   */
  function goalReached() public view returns (bool) {
    return (weiRaised + weiRaisedDuringPrivateSale) >= goal;
  }

  /**
   * @dev Extend parent behavior requiring to be within contributing period
   * @param _beneficiary Token purchaser
   * @param _weiAmount Amount of wei contributed
   */
  function _preValidatePurchase(address _beneficiary, uint256 _weiAmount, uint256 _tokensToBeMinted) internal onlyWhileOpen isWhitelisted(_beneficiary) {
    require(_weiAmount >= minContribution);
    require(weiRaised.add(_weiAmount) <= cap);
    require(tokensToBeMinted.add(_tokensToBeMinted) <= tokenCap);
    super._preValidatePurchase(_beneficiary, _weiAmount, _tokensToBeMinted);
  }


  /**
  * FOR THE PRIVATE SALE LOCKUP
  **/


  /**
   * @dev claim locked tokens only after lockup time.
   */
   
  function claimLockedTokens() public {
    require(hasClosed());
    require(goalReached());
    
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
  function releaseLockedTokensByIndex(address _beneficiary, uint _lockedTimeIndex) onlyOwner public {
    require(hasClosed());
    require(goalReached());
    require(lockupTimes[_lockedTimeIndex] < now);
    uint256 tokens = lockedTokens[_beneficiary][_lockedTimeIndex];
    if (tokens>0){
        lockedTokens[_beneficiary][_lockedTimeIndex] = 0;
        _deliverTokens(_beneficiary, tokens);    
    }
  }
  
  
  function releaseLockedTokens(address _beneficiary) onlyOwner public {
    require(hasClosed());
    require(goalReached());
    
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
  
  function tokensReadyForRelease(uint releaseBatch) public view returns (bool) {
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

  /**
   * LOCKUP - PRIVATE SALE
   * /
   
  /**
   * @dev Add locked tokens per user for private sale.
   * @param _beneficiary Token purchaser
   * @param _atokenAmount Amount of tokens purchased
   */
  function addPrivateSaleWithMonthlyLockup(address _beneficiary, uint256[] _atokenAmount, uint256 _contributionAmount) onlyOwner onlyWhileOpen public {
      require(_beneficiary != address(0));
      require(_contributionAmount > 0);
      uint tokenLen = _atokenAmount.length;
      require(tokenLen == lockupTimes.length);
      
      uint256 existingContribution = privateSale[_beneficiary];
      if (existingContribution > 0){
        updateLockedTokens(_beneficiary, _atokenAmount, _contributionAmount);
      }else{
        lockedTokens[_beneficiary] = _atokenAmount;
        privateSale[_beneficiary] = _contributionAmount;
          
        weiRaisedDuringPrivateSale = weiRaisedDuringPrivateSale.add(_contributionAmount);
        tokensToBeMinted = tokensToBeMinted.add(getTotalTokensPerArray(_atokenAmount));
          
        emit AddLockedTokens(
          _beneficiary,
          _contributionAmount,
          _atokenAmount
        );
          
      }
      
      
  }
  
  function getTotalTokensPerArray(uint256[] _tokensArray) internal pure returns (uint256) {
      uint256 totalTokensPerArray = 0;
      for (uint i=0; i<_tokensArray.length; i++) {
        totalTokensPerArray += _tokensArray[i];
      }
      return totalTokensPerArray;
  }


  function updateLockedTokens(address _beneficiary, uint256[] _atokenAmount, uint256 _contributionAmount) onlyOwner onlyWhileOpen public {
      require(_beneficiary != address(0));
      require(_contributionAmount > 0);
      uint tokenLen = _atokenAmount.length;
      require(tokenLen > 0);
      require(tokenLen == lockupTimes.length);
      
      //subtract to tokenstobeminted
      tokensToBeMinted = tokensToBeMinted.sub(getTotalTokensPerArray(lockedTokens[_beneficiary]));
      
      lockedTokens[_beneficiary] = _atokenAmount;
      
      //add to tokenstobeminted
      tokensToBeMinted = tokensToBeMinted.add(getTotalTokensPerArray(_atokenAmount));
      
      //subtract old contribution
      uint256 oldContributions = privateSale[_beneficiary];
      weiRaisedDuringPrivateSale = weiRaisedDuringPrivateSale.sub(oldContributions);
      
      //add new contribution
      privateSale[_beneficiary] = _contributionAmount;
      weiRaisedDuringPrivateSale = weiRaisedDuringPrivateSale.add(_contributionAmount);
      
      
      emit UpdateLockedTokens(
      _beneficiary,
      _contributionAmount,
      _atokenAmount
    );
  }


}

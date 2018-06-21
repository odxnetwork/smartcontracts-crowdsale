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
contract CrowdsaleRules is CappedCrowdsale, TimedCrowdsale, Ownable {
  using SafeMath for uint256;

  mapping(address => uint256) public balances;
  mapping(address => uint256) public bonuses;
  mapping(address => bool) public whitelist;
  
  mapping(address => uint256) public lockedTokens;
  mapping(address => uint256) public lockupTime;

  
  // end of presale additional tokens multiplier
  uint256 public additionalTokenMultiplier;

  // minimum amount of funds to be raised in weis
  uint256 public goal;

  // minimum contribution
  uint256 public minContribution;
  
  // private sale tracker of contribution
  uint256 public weiRaisedDuringPrivateSale;

  event AllocateBonusTokens(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
  event ClearTokensAfterRefund(address indexed beneficiary, uint256 value);
  event DeliverTokens(address indexed sender, address indexed beneficiary, uint256 value);
  event AddLockedTokens(address indexed beneficiary, uint256 value, uint256 amount);
  event RemoveLockedTokens(address indexed beneficiary);
  

  /**
   * @dev Constructor, sets goal, additionalTokenMultiplier and minContribution
   * @param _goal Funding goal
   */
  constructor(uint256 _minContribution, uint256 _goal, uint256 _additionalTokenMultiplier) public {
    require(_goal > 0);
    require(_minContribution > 0);
    require(_additionalTokenMultiplier > 0);
    
    goal = _goal;
    additionalTokenMultiplier = _additionalTokenMultiplier;
    minContribution = _minContribution;
    
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
    uint256 bonusTokens = bonuses[_beneficiary];
    uint256 totalTokens = amount + bonusTokens;
    require(totalTokens > 0);
    balances[_beneficiary] = 0;
    bonuses[_beneficiary] = 0;
    _deliverTokens(_beneficiary, totalTokens);
    
    emit DeliverTokens(
        msg.sender,
        _beneficiary,
        totalTokens
    );
  }
  
  /**
   * @dev Overrides parent by storing balances instead of issuing tokens right away and adds bonus tokens if applicable.
   * @param _beneficiary Token purchaser
   * @param _tokenAmount Amount of tokens purchased
   */
  function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
    balances[_beneficiary] = balances[_beneficiary].add(_tokenAmount);
    
    if (additionalTokenMultiplier > 0){
        uint256 bonusTokens = (_tokenAmount * additionalTokenMultiplier) / 100;
        bonuses[_beneficiary] = bonuses[_beneficiary].add(bonusTokens);
        
        //updated token count to be minted
        tokensToBeMinted = tokensToBeMinted.add(bonusTokens);
        
        emit AllocateBonusTokens(
            msg.sender,
            _beneficiary,
            msg.value,
            bonusTokens
        );
    }
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
    uint256 _time = lockupTime[msg.sender];
    require(_time > 0);
    require(block.timestamp>_time);
    
    uint256 amount = lockedTokens[msg.sender];
    require(amount > 0);
    lockedTokens[msg.sender] = 0;
    lockupTime[msg.sender] = 0;
    //mint or transfer
    _deliverTokens(msg.sender, amount);
  }

  /**
   * @dev release locked tokens only after lockup time.
   */
  function releaseLockedTokens(address _beneficiary) onlyOwner public {
    require(hasClosed());
    require(goalReached());
    uint256 _time = lockupTime[_beneficiary];
    require(_time > 0);
    require(block.timestamp>_time);
    
    uint256 amount = lockedTokens[_beneficiary];
    require(amount > 0);
    lockedTokens[_beneficiary] = 0;
    lockupTime[_beneficiary] = 0;
    //mint or transfer
    _deliverTokens(_beneficiary, amount);
  }

  /**
   * @dev Add locked tokens per user for private sale.
   * @param _beneficiary Token purchaser
   * @param _tokenAmount Amount of tokens purchased
   */
  function addPrivateSaleWithLockup(address _beneficiary, uint256 _tokenAmount, uint256 _lockupTime, uint256 _contributionAmount) onlyOwner onlyWhileOpen public {
    require(_beneficiary != address(0));
    require(_tokenAmount > 0);
    require(_lockupTime >= now);
    require(_contributionAmount > 0);
    
    //require(lockedTokens[_beneficiary]<=0);
    uint256 lTime = lockupTime[_beneficiary];
    if (lTime>0){
        require(lTime == _lockupTime);
    }
    lockedTokens[_beneficiary] = _tokenAmount;
    lockupTime[_beneficiary] = _lockupTime;
    tokensToBeMinted = tokensToBeMinted.add(_tokenAmount);
    weiRaisedDuringPrivateSale = weiRaisedDuringPrivateSale.add(_contributionAmount);

    emit AddLockedTokens(
      _beneficiary,
      _contributionAmount,
      _tokenAmount
    );
  }

  /**
   * @dev Add locked tokens per user for private sale (bulk)
   * @param _beneficiaries Token purchaser
   * @param _tokenAmount Amount of tokens purchased
   * @param _contributionAmount total contribution in wei
   * @param _lockupTime lockup time
   */
  function addBulkPrivateSaleWithLockup(address[] _beneficiaries, uint256 _tokenAmount, uint256 _contributionAmount, uint256 _lockupTime) onlyOwner onlyWhileOpen public {
    for (uint256 i = 0; i < _beneficiaries.length; i++) {
      if (lockedTokens[_beneficiaries[i]]<=0){
            address beneficiary = _beneficiaries[i];
            require(beneficiary != address(0));
            require(_tokenAmount > 0);
            require(_lockupTime >= now);
            require(_contributionAmount > 0);
            uint256 lTime = lockupTime[beneficiary];
            if (lTime>0){
                require(lTime == _lockupTime);
            }
            lockedTokens[beneficiary] = _tokenAmount;
            lockupTime[beneficiary] = _lockupTime;
            tokensToBeMinted = tokensToBeMinted.add(_tokenAmount);
            weiRaisedDuringPrivateSale = weiRaisedDuringPrivateSale.add(_contributionAmount);

            emit AddLockedTokens(
              beneficiary,
              _contributionAmount,
              _tokenAmount
            );
      }
    }
  }
  
  
  /**
   * @dev Returns the locked tokens of a specific user.
   * @param _beneficiary Address whose locked tokens is to be checked
   * @return locked tokens for individual user
   */
  function getLockedTokensPerUser(address _beneficiary) public view returns (uint256) {
    return lockedTokens[_beneficiary];
  }

  /**
   * @dev Returns the lockup tiime of a specific user.
   * @param _beneficiary Address whose lockup time is to be checked
   * @return lockup time for individual user
   */
  function getLockUpTimePerUser(address _beneficiary) public view returns (uint256) {
    return lockupTime[_beneficiary];
  }


}

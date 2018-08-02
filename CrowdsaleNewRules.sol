pragma solidity ^0.4.23;

import "./TimedCrowdsale.sol";
import "./CappedCrowdsale.sol";
import "./WhitelistedCrowdsale.sol";
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
 * 080118 - removed unused events 
 */
contract CrowdsaleNewRules is CappedCrowdsale, TimedCrowdsale, WhitelistedCrowdsale {
  using SafeMath for uint256;

  // minimum amount of funds to be raised in weis
  uint256 public goal;

  // minimum contribution
  uint256 public minContribution;

  mapping(address => uint256) public balances;
  
  event DeliverTokens(address indexed sender, address indexed beneficiary, uint256 value);
  event UpdateRate(address indexed sender, uint256 rate);
  


  /**
   * @dev Constructor, sets goal, additionalTokenMultiplier and minContribution
   * @param _goal Funding goal
   */
  constructor(uint256 _minContribution, uint256 _goal) public {
    require(_goal > 0);
    require(_minContribution > 0);
    
    goal = _goal;
    minContribution = _minContribution;
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
    return weiRaised >= goal;
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
   * @dev change rate value
   * @param _newrate new token conversion rate
   */
  function updateRate(uint256 _newrate) external onlyOwner {
    require(_newrate > 0);
    rate = _newrate;
    
    emit UpdateRate(
        msg.sender,
        _newrate
    );
  }


}

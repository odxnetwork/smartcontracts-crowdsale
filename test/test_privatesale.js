const BigNumber = web3.BigNumber;
const should = require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BigNumber))
    .should();
const EVMThrow = 'invalid opcode';
module.exports = { should, EVMThrow };

const MockODXPrivatesale = artifacts.require("MockODXPrivatesale");
const ODXToken = artifacts.require("ODXToken");

contract('MockODXPrivatesale', function(accounts) {
  const owner = accounts[0];
  const investor = accounts[1];
  const otherInvestor = accounts[2];
  const privatesaleAgent = accounts[3];
  const amount = 1000;
  const amount2 = 2000;
  const amount3 = 3000;
  const contribution = 50;
  const tokenArray = [amount,amount2,amount3];
  const tokenArrayIncomplete = [amount,amount2];
  const tokenArrayMore = [amount,amount2,amount3,amount];
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  const fiveMinutes = 60*5;
  const tenMinutes = 60*10;
  
  beforeEach(async function () {
    this.token = await ODXToken.new("ODX Test Token 01", "ODXT", 18, "1000000000000000000000000000", { from: owner });
    this.crowdsale = await MockODXPrivatesale.new(
        this.token.address, 
        { from: owner }
    );
    await this.token.setMintAgent(this.crowdsale.address, true, { from: owner });
    await this.crowdsale.setPrivateSaleAgent(privatesaleAgent, true, { from: owner });
  });

  describe('setPrivateSaleAgent', function () {
    it('should only allow owner to set privatesaleAgent', async function () {
        await this.crowdsale.setPrivateSaleAgent(investor, true, { from: owner }).should.be.fulfilled;
        const isPrivateSaleAgent = await this.crowdsale.privateSaleAgents(investor);
        isPrivateSaleAgent.should.be.equal(true);
        await this.crowdsale.setPrivateSaleAgent(investor, true, { from: investor }).should.be.rejected;
    });
  });
  
  describe('addPrivateSaleWithMonthlyLockup', function () {
    it('should only allow privatesaleAgent/owner to call updatePrivateSaleWithMonthlyLockup', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: investor }).should.be.rejected;
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent }).should.be.fulfilled;
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(otherInvestor, tokenArray, contribution, { from: owner }).should.be.fulfilled;
        const tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(amount + amount2 + amount3);
    });
    it('should reject investor has extisting privatesale contribution must use updatePrivateSaleWithMonthlyLockupByIndex', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent }).should.be.rejected;
    });
    it('should reject if contribution is <= 0 ', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, 0, { from: privatesaleAgent }).should.be.rejected;
    });
    it('should reject if investor is not valid ', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(null, tokenArray, contribution, { from: privatesaleAgent }).should.be.rejected;
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(0, tokenArray, contribution, { from: privatesaleAgent }).should.be.rejected;
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(ZERO_ADDRESS, tokenArray, contribution, { from: privatesaleAgent }).should.be.rejected;
    });
    it('should reject if tokens are incomplete', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArrayIncomplete, contribution, { from: privatesaleAgent }).should.be.rejected;
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArrayMore, contribution, { from: privatesaleAgent }).should.be.rejected;
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, [], contribution, { from: privatesaleAgent }).should.be.rejected;
    });
    it('should log update locked tokens', async function () {
        const { logs } = await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        const event = logs.find(e => e.event === 'AddLockedTokens');
        should.exist(event);
        event.args.beneficiary.should.equal(investor);
        event.args.totalContributionAmount.should.be.bignumber.equal(contribution);
    });
  });
  
  describe('updatePrivateSaleWithMonthlyLockupByIndex', function () {
    it('should only allow privatesaleAgent to call updatePrivateSaleWithMonthlyLockupByIndex', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.updatePrivateSaleWithMonthlyLockupByIndex(investor, 0, amount2, contribution, { from: investor }).should.be.rejected;
    });
    it('should change token amount of the lockupindex', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.updatePrivateSaleWithMonthlyLockupByIndex(investor, 0, amount2, contribution, { from: privatesaleAgent });
        const tArray = await this.crowdsale.getLockedTokensPerUser(investor);
        tArray[0].should.be.bignumber.equal(amount2);
    });
    it('should reject if contribution is <= 0 ', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.updatePrivateSaleWithMonthlyLockupByIndex(investor, 0, amount2, 0, { from: privatesaleAgent }).should.be.rejected;
    });
    it('should reject if lockupIndex is not within lockeduptimes length ', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.updatePrivateSaleWithMonthlyLockupByIndex(investor, 4, amount2, contribution, { from: privatesaleAgent }).should.be.rejected;
    });
    it('should reject if investor has no existing contribution ', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.updatePrivateSaleWithMonthlyLockupByIndex(otherInvestor, 0, amount2, contribution, { from: privatesaleAgent }).should.be.rejected;
    });
    it('should reject if lockuptime of index is greater than current date ', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.turnBackTime(tenMinutes+1);
        await this.crowdsale.updatePrivateSaleWithMonthlyLockupByIndex(investor, 0, amount2, contribution, { from: privatesaleAgent }).should.be.rejected;
    });
    it('should log update locked tokens', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        const { logs } = await this.crowdsale.updatePrivateSaleWithMonthlyLockupByIndex(investor, 0, amount2, contribution, { from: privatesaleAgent });
        const event = logs.find(e => e.event === 'UpdateLockedTokens');
        should.exist(event);
        event.args.beneficiary.should.equal(investor);
        event.args.totalContributionAmount.should.be.bignumber.equal(contribution);
        event.args.lockedTimeIndex.should.be.bignumber.equal(0);
        event.args.tokenAmount.should.be.bignumber.equal(amount2);
    });
    
  });
  describe('token distribution/release', function () {
    it('should not allow investor to claim tokens before lockup time', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.claimLockedTokens({ from: investor });
        //lockedtokens are the same
        const tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(amount + amount2 + amount3);
        //no released tokens
        const releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(0);
    });
    it('should allow investor to claim locked tokens past lockup time', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(otherInvestor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.turnBackTime(tenMinutes+1);
        //release first lockup
        await this.crowdsale.claimLockedTokens({ from: investor });
        let tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(amount2 + amount3);
        let releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(amount);
        //release second lockup
        await this.crowdsale.turnBackTime(fiveMinutes);
        await this.crowdsale.claimLockedTokens({ from: investor });
        tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(amount3);
        releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(amount + amount2);
        //release third lockup
        await this.crowdsale.turnBackTime(fiveMinutes);
        await this.crowdsale.claimLockedTokens({ from: investor });
        tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(0);
        releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(amount + amount2 + amount3);

        //release all tokens 
        await this.crowdsale.claimLockedTokens({ from: otherInvestor });
        tArray = await this.crowdsale.getTotalLockedTokensPerUser(otherInvestor);
        tArray.should.be.bignumber.equal(0);
        releasedTokens = await this.token.balanceOf(otherInvestor);
        releasedTokens.should.be.bignumber.equal(amount + amount2 + amount3);
    });
    it('should allow owner to release locked tokens past lockup time', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(otherInvestor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.turnBackTime(tenMinutes+1);
        //release first lockup
        await this.crowdsale.releaseLockedTokens(investor, { from: owner });
        let tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(amount2 + amount3);
        let releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(amount);
        //release second lockup
        await this.crowdsale.turnBackTime(fiveMinutes);
        await this.crowdsale.releaseLockedTokens(investor, { from: owner });
        tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(amount3);
        releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(amount + amount2);
        //release third lockup
        await this.crowdsale.turnBackTime(fiveMinutes);
        await this.crowdsale.releaseLockedTokens(investor, { from: owner });
        tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(0);
        releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(amount + amount2 + amount3);

        //release all tokens 
        await this.crowdsale.releaseLockedTokens(otherInvestor, { from: owner });
        tArray = await this.crowdsale.getTotalLockedTokensPerUser(otherInvestor);
        tArray.should.be.bignumber.equal(0);
        releasedTokens = await this.token.balanceOf(otherInvestor);
        releasedTokens.should.be.bignumber.equal(amount + amount2 + amount3);
    });
    it('should allow owner to release locked tokens past lockup time by index', async function () {
        await this.crowdsale.addPrivateSaleWithMonthlyLockup(investor, tokenArray, contribution, { from: privatesaleAgent });
        await this.crowdsale.turnBackTime(tenMinutes+1);
        //release first lockup
        await this.crowdsale.releaseLockedTokensByIndex(investor, 0, { from: owner });
        let tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(amount2 + amount3);
        let releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(amount);
        //release second lockup
        await this.crowdsale.turnBackTime(tenMinutes);
        await this.crowdsale.releaseLockedTokensByIndex(investor, 1, { from: owner });
        tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(amount3);
        releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(amount + amount2);
        //release third lockup
        await this.crowdsale.releaseLockedTokensByIndex(investor, 2, { from: owner });
        tArray = await this.crowdsale.getTotalLockedTokensPerUser(investor);
        tArray.should.be.bignumber.equal(0);
        releasedTokens = await this.token.balanceOf(investor);
        releasedTokens.should.be.bignumber.equal(amount + amount2 + amount3);
    });

  });

  
  describe('transferOwnership', function () {
    it("should only allow owner to transfer ownership", async function() {
      await this.crowdsale.transferOwnership(investor, { from: otherInvestor }).should.be.rejected;
      await this.crowdsale.transferOwnership(otherInvestor, { from: owner }).should.be.fulfilled;
      const ret = await this.crowdsale.owner();
      ret.should.be.equal(otherInvestor);
    });
    
    it('should guard ownership against stuck state', async function () {
      await this.crowdsale.transferOwnership(null, { from: owner }).should.be.rejected;
      await this.crowdsale.transferOwnership(ZERO_ADDRESS, { from: owner }).should.be.rejected;
    });

  });
  

});
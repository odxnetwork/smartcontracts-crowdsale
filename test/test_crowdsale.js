const BigNumber = web3.BigNumber;
const should = require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BigNumber))
    .should();
const EVMThrow = 'invalid opcode';
module.exports = { should, EVMThrow };

const MockODXCrowdsale = artifacts.require("MockODXCrowdsale");
const ODXToken = artifacts.require("ODXToken");

contract('MockODXCrowdsale', function(accounts) {
  const owner = accounts[0];
  const whitelistedInvestor = accounts[1];
  const otherInvestor = accounts[2];
  const anotherInvestor = accounts[3];
  const whitelistAgentAddress = accounts[4];
  const ETHRateAgent = accounts[5];
  const value = 1000000000000000000;
  const lessMinValue = 10000000000000000;
  const lessThanTokenCap = 10000000000000000000000;
  const moreThanTokenCap = 60000000000000000000000;
  const rate = 50000;
  const newRate = 1000;
  const one_eth = web3.toWei(1, 'ether');
  const fundWallet = "0x3f60ea8b4b6dd132a2f4d15fe3c157f201818f13";
  const days30 = 60 * 60 * 24 * 30;
  
  beforeEach(async function () {
    const startTime = Math.round((new Date(Date.now()).getTime())/1000);
    
    this.token = await ODXToken.new("ODX Test Token 01", "ODXT", 18, "1000000000000000000000000000", { from: owner });
    this.crowdsale = await MockODXCrowdsale.new(
        rate,
        fundWallet,
        1000000000000000000,
        50000000000000000000000,
        this.token.address,
        100000000000000000,
        startTime, 
        { from: owner }
    );
    await this.token.setMintAgent(this.crowdsale.address, true, { from: owner });
    await this.crowdsale.addToWhitelist(whitelistedInvestor, { from: owner });
  });

  describe('crowdsale is active', function () {
    describe('contribution', function () {
        describe('sender is whitelisted', function () {
            it('should accept contribution equal or more than minimum', async function () {
                await this.crowdsale.buyTokens(whitelistedInvestor, { value: value, from: whitelistedInvestor }).should.be.fulfilled;
            });
            it('should reject contribution less than minimum', async function () {
                await this.crowdsale.buyTokens(whitelistedInvestor, { value: lessMinValue, from: whitelistedInvestor }).should.be.rejected;
            });
            it('1 ETH should be equivalent to ' + rate + ' ODX tokens', async function () {
                await this.crowdsale.buyTokens(whitelistedInvestor, { value: one_eth, from: whitelistedInvestor }).should.be.fulfilled;
            });
            it('should forward funds to wallet', async function () {
                const pre = web3.eth.getBalance(fundWallet);
                await this.crowdsale.sendTransaction({ value, from: whitelistedInvestor });
                const post = web3.eth.getBalance(fundWallet);
                post.minus(pre).should.be.bignumber.equal(value);
            });
            it('should assign tokens to sender', async function () {
                const expectedTokenAmount = new BigNumber(rate * value);
                await this.crowdsale.sendTransaction({ value: value, from: whitelistedInvestor });
                let balance = await this.crowdsale.balances(whitelistedInvestor);
                balance.should.be.bignumber.equal(expectedTokenAmount);
            });
            it('should log token allocation', async function () {
              const { logs } = await this.crowdsale.sendTransaction({ value: value, from: whitelistedInvestor });
              const expectedTokenAmount = new BigNumber(rate * value);
              const event = logs.find(e => e.event === 'AllocateTokens');
              should.exist(event);
              event.args.purchaser.should.equal(whitelistedInvestor);
              event.args.beneficiary.should.equal(whitelistedInvestor);
              event.args.value.should.be.bignumber.equal(value);
              event.args.amount.should.be.bignumber.equal(expectedTokenAmount);
            });
        });    
        describe('sender is not whitelisted', function () {
            it('should reject any contribution : equal or more than minimum', async function () {
                await this.crowdsale.buyTokens(otherInvestor, { value: value, from: otherInvestor }).should.be.rejected;
            });
            it('should reject any contribution :  less than minimum', async function () {
                await this.crowdsale.buyTokens(otherInvestor, { value: lessMinValue, from: otherInvestor }).should.be.rejected;
            });
            it('should reject payments to addresses removed from whitelist', async function () {
                await this.crowdsale.removeFromWhitelist(whitelistedInvestor);
                await this.crowdsale.buyTokens(whitelistedInvestor, { value: value, from: whitelistedInvestor }).should.be.rejected;
            });
        });  
    
    });

    describe('whitelisting', function () {
      it('should only allow owner to set WhitelistAgent', async function () {
        await this.crowdsale.setWhitelistAgent(whitelistedInvestor, true, { from: owner }).should.be.fulfilled;
        await this.crowdsale.setWhitelistAgent(whitelistedInvestor, true, { from: whitelistedInvestor }).should.be.rejected;
      });
      it('should only allow WhitelistAgents/owner to whitelist an investor', async function () {
        await this.crowdsale.setWhitelistAgent(whitelistAgentAddress, true, { from: owner }).should.be.fulfilled;
        await this.crowdsale.addToWhitelist(otherInvestor, { from: otherInvestor }).should.be.rejected;
        await this.crowdsale.addToWhitelist(otherInvestor, { from: owner }).should.be.fulfilled;
        await this.crowdsale.addToWhitelist(anotherInvestor, { from: whitelistAgentAddress }).should.be.fulfilled;
      });
      it('should correctly report whitelisted addresses', async function () {
        let isAuthorized = await this.crowdsale.whitelist(whitelistedInvestor);
        isAuthorized.should.equal(true);
        let isntAuthorized = await this.crowdsale.whitelist(otherInvestor);
        isntAuthorized.should.equal(false);
      });
    });

    describe('update rate', function () {
      it('should only allow owner to set ETHRateAgent', async function () {
        await this.crowdsale.setETHRateAgent(ETHRateAgent, true, { from: owner }).should.be.fulfilled;
        await this.crowdsale.setETHRateAgent(ETHRateAgent, true, { from: ETHRateAgent }).should.be.rejected;
      });
          
      it('should reject request if sender is not the ETHRateAgents/owner', async function () {
        await this.crowdsale.updateRate(newRate, { from: otherInvestor }).should.be.rejected;
      });
      it('should successfully change rate if sender is owner', async function () {
        await this.crowdsale.updateRate(newRate, { from: owner }).should.be.fulfilled;
        let newRateBC = await this.crowdsale.rate();
        newRateBC.should.be.bignumber.equal(newRate);
      });
      it('should successfully change rate if sender is ETHRateAgents', async function () {
        await this.crowdsale.setETHRateAgent(ETHRateAgent, true, { from: owner }).should.be.fulfilled;
        await this.crowdsale.updateRate(newRate, { from: ETHRateAgent }).should.be.fulfilled;
        let newRateBC = await this.crowdsale.rate();
        newRateBC.should.be.bignumber.equal(newRate);
      });
    });

    
    describe('add purchase from other source', function () {
      it('should only allow owner to set allowedAgentsForOtherSource', async function () {
        await this.crowdsale.setAllowedAgentsForOtherSource(ETHRateAgent, true, { from: owner }).should.be.fulfilled;
        await this.crowdsale.setAllowedAgentsForOtherSource(ETHRateAgent, true, { from: ETHRateAgent }).should.be.rejected;
      });
          
      it('should reject request if sender is not the allowedAgentsForOtherSource/owner', async function () {
        await this.crowdsale.addPurchaseFromOtherSource(whitelistedInvestor, "BTC", lessThanTokenCap, lessThanTokenCap, { from: ETHRateAgent }).should.be.rejected;
      });
      it('should successfully addpurchasefromothersource if sender is allowedAgentsForOtherSource/owner', async function () {
        await this.crowdsale.setAllowedAgentsForOtherSource(ETHRateAgent, true, { from: owner }).should.be.fulfilled;
        await this.crowdsale.addPurchaseFromOtherSource(whitelistedInvestor, "BTC", lessThanTokenCap, lessThanTokenCap, { from: owner }).should.be.fulfilled;
        await this.crowdsale.addPurchaseFromOtherSource(whitelistedInvestor, "BTC", lessThanTokenCap, lessThanTokenCap, { from: ETHRateAgent }).should.be.fulfilled;
      });
      it('should reject request if token is more than tokencap', async function () {
        await this.crowdsale.addPurchaseFromOtherSource(whitelistedInvestor, "BTC", moreThanTokenCap, moreThanTokenCap, { from: owner }).should.be.rejected;
        await this.crowdsale.addPurchaseFromOtherSource(whitelistedInvestor, "BTC", lessThanTokenCap, lessThanTokenCap, { from: owner }).should.be.fulfilled;
      });
      it('should reject request if beneficiary is not whitelisted', async function () {
        await this.crowdsale.addPurchaseFromOtherSource(otherInvestor, "BTC", lessThanTokenCap, lessThanTokenCap, { from: owner }).should.be.rejected;
        await this.crowdsale.addPurchaseFromOtherSource(otherInvestor, "BTC", lessThanTokenCap, lessThanTokenCap, { from: owner }).should.be.rejected;
      });
    });


    describe('token delivery', function () {
      it('should not immediately assign tokens to beneficiary', async function () {
          await this.crowdsale.buyTokens(whitelistedInvestor, { value: value, from: whitelistedInvestor }).should.be.fulfilled;
          const balance = await this.token.balanceOf(whitelistedInvestor);
          balance.should.be.bignumber.equal(0);
      });

      it('should not allow beneficiaries to withdraw tokens before crowdsale ends', async function () {
          await this.crowdsale.buyTokens(whitelistedInvestor, { value: value, from: whitelistedInvestor }).should.be.fulfilled;
          await this.crowdsale.withdrawTokensByInvestors({ from: whitelistedInvestor }).should.be.rejected;
      });

    });
  });

  describe('crowdsale is not active', function () {
    describe('contribution', function () {
        it('should reject any contribution if crowdsale is not active', async function () {
            await this.crowdsale.turnBackTime(days30+1);
            await this.crowdsale.buyTokens(whitelistedInvestor, { value: value, from: whitelistedInvestor }).should.be.rejected;
            await this.crowdsale.buyTokens(otherInvestor, { value: value, from: otherInvestor }).should.be.rejected;
        });
    });
    describe('token delivery', function () {
        it('should allow whitelisted beneficiaries to withdraw tokens after crowdsale if goal is reached', async function () {
            await this.crowdsale.buyTokens(whitelistedInvestor, { value: value, from: whitelistedInvestor });
            const tokenAllocated = await this.crowdsale.balances(whitelistedInvestor);
            await this.crowdsale.turnBackTime(days30+1);
            await this.crowdsale.withdrawTokensByInvestors({ from: whitelistedInvestor }).should.be.fulfilled;
            const tokenReceived = await this.token.balanceOf(whitelistedInvestor);
            tokenAllocated.should.be.bignumber.equal(tokenReceived);
        });
        
        it('should log token distribution', async function () {
          await this.crowdsale.buyTokens(whitelistedInvestor, { value: value, from: whitelistedInvestor });
          const tokenAllocated = await this.crowdsale.balances(whitelistedInvestor);
          await this.crowdsale.turnBackTime(days30+1);
          const { logs } = await this.crowdsale.withdrawTokensByInvestors({ from: whitelistedInvestor });
          const event = logs.find(e => e.event === 'DeliverTokens');
          should.exist(event);
          event.args.sender.should.equal(whitelistedInvestor);
          event.args.beneficiary.should.equal(whitelistedInvestor);
          event.args.value.should.be.bignumber.equal(tokenAllocated);
        });
    });
  });

  
  describe('transferOwnership', function () {
    it("should only allow owner to transfer ownership", async function() {
      await this.crowdsale.transferOwnership(anotherInvestor, { from: otherInvestor }).should.be.rejected;
      await this.crowdsale.transferOwnership(otherInvestor, { from: owner }).should.be.fulfilled;
      const ret = await this.crowdsale.owner();
      ret.should.be.equal(otherInvestor);
    });
    
    it('should guard ownership against stuck state', async function () {
      await this.crowdsale.transferOwnership(null, { from: owner }).should.be.rejected;
    });

  });
  
});
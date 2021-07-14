const { expectRevert } = require('@openzeppelin/test-helpers');
const HammyToken = artifacts.require('HammyToken');

describe('HammyToken', async () => {
  beforeEach(async () => {
    const [naruto, goku, sasuke, satoshi] = await web3.eth.getAccounts();
    this.naruto = naruto;
    this.goku = goku;
    this.sasuke = sasuke;
    this.satoshi = satoshi;
  });

  it('deployment', async () => {
    const hammy = await HammyToken.new({ from: this.naruto });
    assert.equal(await hammy.totalSupply(), '0');
  });

  it('anti whale', async () => {
    const hammy = await HammyToken.new({ from: this.naruto });
    await hammy.mint(this.goku, web3.utils.toWei('1000', 'ether'), { from: this.naruto });
    await hammy.updateMaxTransferAmountRate(1, { from: this.naruto });

    assert.equal(await hammy.totalSupply(), web3.utils.toWei('1000', "ether"));
    assert.equal(await hammy.balanceOf(this.goku), web3.utils.toWei('1000', "ether"));
    assert.equal(await hammy.maxTransferAmount(), web3.utils.toWei('0.1', "ether"));

    await expectRevert(hammy.transfer(this.sasuke, web3.utils.toWei('1000', "ether"), { from: this.goku }), 'HAMMY::antiWhale: Transfer amount exceeds the maxTransferAmount');
    await hammy.transfer(this.sasuke, web3.utils.toWei('0.1', 'ether'), { from: this.goku });
  });

  it('permission', async () => {
    const hammy = await HammyToken.new({ from: this.naruto });
    await expectRevert(hammy.mint(this.goku, 20, { from: this.goku }), 'Ownable: caller is not the owner');
    await expectRevert(hammy.updateMaxTransferAmountRate(20, { from: this.goku }), 'operator: caller is not the operator');
    await expectRevert(hammy.updateMaxTransferAmountRate(10001, { from: this.naruto }), 'HAMMY::updateMaxTransferAmountRate: Max transfer amount rate must not exceed the maximum rate.');
  });
});

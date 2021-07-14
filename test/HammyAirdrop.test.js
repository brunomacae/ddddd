const { expectRevert } = require('@openzeppelin/test-helpers');
const HammyToken = artifacts.require('HammyToken');
const HammyAirdrop = artifacts.require('HammyAirdrop');

describe('HammyAirdrop', async () => {
  beforeEach(async () => {
    const [naruto, goku, sasuke, satoshi] = await web3.eth.getAccounts();
    this.naruto = naruto;
    this.goku = goku;
    this.sasuke = sasuke;
    this.satoshi = satoshi;
  });

  it('real case', async () => {
    const hammy = await HammyToken.new({ from: this.naruto });
    await hammy.mint(this.naruto, web3.utils.toWei('500', 'ether'), { from: this.naruto });
    assert.equal(await hammy.totalSupply(), web3.utils.toWei('500', 'ether'));

    const airdrop = await HammyAirdrop.new(hammy.address, Math.round(new Date() / 1000), web3.utils.toWei('0.1', 'ether'), { from: this.naruto });
    await hammy.setExcludedFromAntiWhale(airdrop.address, { from: this.naruto });
    await hammy.transfer(airdrop.address, web3.utils.toWei('0.3', 'ether'), { from: this.naruto });

    assert.equal(await airdrop.available(this.goku), web3.utils.toWei('0.1', 'ether'));
    assert.equal(await airdrop.available(this.sasuke), web3.utils.toWei('0.1', 'ether'));
    assert.equal(await airdrop.available(this.satoshi), web3.utils.toWei('0.1', 'ether'));

    await airdrop.claim({ from: this.goku });
    assert.equal(await hammy.balanceOf(this.goku), web3.utils.toWei('0.1', 'ether'));
    await expectRevert(airdrop.claim({ from: this.goku }), 'already claimed!');

    await airdrop.claim({ from: this.sasuke });
    await airdrop.claim({ from: this.satoshi });

    await expectRevert(airdrop.claim({ from: this.goku }), 'sold out');
  });
});

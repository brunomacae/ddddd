// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";

import "./VaultController.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IMasterChef.sol";
import "../interfaces/IHammyMinter.sol";

contract VaultHammyBNB is IStrategy, VaultController {
    using SafeBEP20 for IBEP20;
    using SafeMath for uint256;

    BEP20 public constant HAMMY_BNB = BEP20(0xA61995a54cc5a5bFc52879cCa2DCA6bB8406E095);

    uint public override pid = 0;
    uint private _totalShares;
    mapping (address => uint) private _shares;
    mapping (address => uint) private _rewarded;
    mapping (address => uint) private _depositedAt;

    /* ========== INITIALIZER ========== */

    function initialize() external initializer {
        __VaultController_init(IBEP20(HAMMY_BNB));
    }

    function totalSupply() override public view returns (uint) {
        return _totalShares;
    }

    function balance() override public view returns (uint) {
        return HAMMY_BNB.balanceOf(address(this));
    }

    function balanceOf(address account) override public view returns(uint) {
        return _shares[account];
    }

    function withdrawableBalanceOf(address account) override public view returns (uint) {
        return _shares[account];
    }

    function sharesOf(address account) override public view returns (uint) {
        return _shares[account];
    }

    function principalOf(address account) override public view returns (uint) {
        return _shares[account];
    }

    function depositedAt(address account) override public view returns (uint) {
        return _depositedAt[account];
    }

    function earned(address account) override external view returns (uint) {
        return profitOf(account);
    }

    function profitOf(address account) override public view returns (uint) {
        if (address(_minter) == address(0) || !_minter.isMinter(address(this))) {
            return 0;
        }

        return _minter.amountHammyToMintForHammyBNB(balanceOf(account), block.timestamp.sub(_depositedAt[account])).add(_rewarded[account]);
    }

    function priceShare() override public view returns(uint) {
        return balance().mul(1e18).div(_totalShares);
    }

    function rewardsToken() override external view returns (address) {
        return address(HAMMY);
    }

    function _depositTo(uint _amount, address _to) private {
        _stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        uint amount = _shares[_to];
        if (amount != 0 && _depositedAt[_to] != 0) {
            uint duration = block.timestamp.sub(_depositedAt[_to]);
            _rewarded[_to] = _rewarded[_to].add(_minter.amountHammyToMintForHammyBNB(_shares[_to], duration));
        }

        _totalShares = _totalShares.add(_amount);
        _shares[_to] = _shares[_to].add(_amount);
        _depositedAt[_to] = block.timestamp;
    }

    function deposit(uint _amount) override public {
        _depositTo(_amount, msg.sender);
    }

    function depositAll() override external {
        deposit(_stakingToken.balanceOf(msg.sender));
    }

    function withdrawAll() override external {
        uint _withdraw = balanceOf(msg.sender);

        if (_withdraw > 0) {
            withdraw(_withdraw);
        }

        getReward();
    }

    function mintHammy(address account, uint amount) private {
        if (address(_minter) == address(0) || !_minter.isMinter(address(this))) {
            return;
        }

        _minter.mint(amount);
        _minter.safeHammyTransfer(account, amount);
    }

    function harvest() override external {}

    function withdraw(uint256 amount) override public {
        require(amount <= _shares[msg.sender], "VaultHammyBNB: !amount");

        uint depositTimestamp = _depositedAt[msg.sender];
        _rewarded[msg.sender] = _rewarded[msg.sender].add(_minter.amountHammyToMintForHammyBNB(_shares[msg.sender], block.timestamp.sub(depositTimestamp)));

        _totalShares = _totalShares.sub(_shares[msg.sender]);
        _shares[msg.sender] = _shares[msg.sender].sub(amount);

        _stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, 0);
    }

    function getReward() override public {
        uint profit = profitOf(msg.sender);

        mintHammy(msg.sender, profit);
        delete _rewarded[msg.sender];
        _depositedAt[msg.sender] = block.timestamp;

        emit HammyPaid(msg.sender, profit, 0);
    }
}

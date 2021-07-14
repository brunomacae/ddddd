// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IStrategy.sol";
import "../interfaces/IHammyMinter.sol";
import "../interfaces/IHammyChef.sol";
import "./VaultController.sol";


contract VaultHammy is VaultController, IStrategy, ReentrancyGuardUpgradeable {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    /* ========== STATE VARIABLES ========== */

    uint public override pid;
    uint private _totalSupply;
    mapping(address => uint) private _balances;
    mapping(address => uint) private _depositedAt;
    address public rewardDistributor;

    /* ========== INITIALIZER ========== */

    function initialize() external initializer {
        __VaultController_init(IBEP20(HAMMY));
        __ReentrancyGuard_init();
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view override returns (uint) {
        return _totalSupply;
    }

    function balance() external view override returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint) {
        return _balances[account];
    }

    function sharesOf(address account) external view override returns (uint) {
        return _balances[account];
    }

    function principalOf(address account) external view override returns (uint) {
        return _balances[account];
    }

    function depositedAt(address account) external view override returns (uint) {
        return _depositedAt[account];
    }

    function withdrawableBalanceOf(address account) public view override returns (uint) {
        return _balances[account];
    }

    function rewardsToken() external view override returns (address) {
        return address(HAMMY);
    }

    function priceShare() external view override returns (uint) {
        return 1e18;
    }

    function earned(address) override public view returns (uint) {
        return 0;
    }

    function profitOf(address account) override external view returns (uint) {
        return _hammyChef.pendingHammy(address(this), account);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function deposit(uint amount) override public nonReentrant {
        _deposit(amount, msg.sender);
    }

    function depositTo(uint amount, address to) external {
        require(msg.sender == rewardDistributor, "VaultHammy not reward distributor");
        _deposit(amount, to);
    }

    function depositAll() override external nonReentrant {
        deposit(_stakingToken.balanceOf(msg.sender));
    }

    function withdraw(uint amount) override public nonReentrant {
        require(amount > 0, "VaultHammy: amount must be greater than zero");
        _hammyChef.notifyWithdrawn(msg.sender, amount);

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);

        _stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, 0);
    }

    function withdrawAll() external override {
        uint _withdraw = withdrawableBalanceOf(msg.sender);
        if (_withdraw > 0) {
            withdraw(_withdraw);
        }
        getReward();
    }

    function getReward() public override nonReentrant {
        uint hammyAmount = _hammyChef.safeHammyTransfer(msg.sender);
        emit HammyPaid(msg.sender, hammyAmount, 0);
    }

    function harvest() public override {}

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setMinter(address newMinter) override public onlyOwner {
        VaultController.setMinter(newMinter);
        rewardDistributor = newMinter;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _deposit(uint amount, address _to) private notPaused {
        require(amount > 0, "VaultHammy: amount must be greater than zero");
        _totalSupply = _totalSupply.add(amount);
        _balances[_to] = _balances[_to].add(amount);
        _depositedAt[_to] = block.timestamp;
        _stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        _hammyChef.notifyDeposited(_to, amount);
        emit Deposited(_to, amount);
    }
}

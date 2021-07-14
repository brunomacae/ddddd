// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";

import "./PancakeSwap.sol";
import "../interfaces/IHammyMinter.sol";
import "../interfaces/IPriceCalculator.sol";

interface IStakingRewards {
    function depositTo(uint amount, address to) external;
}

contract HammyMinter is IHammyMinter, PancakeSwap {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    IBEP20  private constant HAMMY = IBEP20(0x3dA288A6BBdD8f1FD155887EECf222D9aa8B8f3d);
    address private constant DEV   = 0xdCEFFb505d5F006E0D2E8e9d2fDBd604D38b8B8b;
    address private constant DEAD  = 0x000000000000000000000000000000000000dEaD;

    IPriceCalculator public constant CALCULATOR = IPriceCalculator(0x93D98e941d54100955eDB179876014485f0eC024);
    IStakingRewards public constant REWARD_POOL = IStakingRewards(0x94Ae0877b892e04868227a0E073A857716F89B3a);

    uint public override WITHDRAWAL_FEE_FREE_PERIOD;
    uint public override WITHDRAWAL_FEE;
    uint public FEE_MAX;

    uint public PERFORMANCE_FEE;

    uint public override hammyPerProfitBNB;
    uint public hammyPerHammyBNBFlip;

    mapping (address => bool) private _minters;

    modifier onlyMinter {
        require(isMinter(msg.sender), "not minter");
        _;
    }

    function initialize() external initializer {
        __PancakeSwap_init();

        HAMMY.safeApprove(address(REWARD_POOL), 0);
        HAMMY.safeApprove(address(REWARD_POOL), uint256(-1));

        FEE_MAX = 10000;
        WITHDRAWAL_FEE = 100; // 1%
        WITHDRAWAL_FEE_FREE_PERIOD = 3 days;
        PERFORMANCE_FEE = FEE_MAX; // 100%
    }

    function transferHammyOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "zero token owner");
        Ownable(address(HAMMY)).transferOwnership(_owner);
    }

    function setWithdrawalFee(uint _fee) external onlyOwner {
        require(_fee < 500, "wrong fee");   // less 5%
        WITHDRAWAL_FEE = _fee;
    }

    function setPerformanceFee(uint _fee) external onlyOwner {
        require(_fee <= FEE_MAX, "wrong fee");
        PERFORMANCE_FEE = _fee;
    }

    function setWithdrawalFeeFreePeriod(uint _period) external onlyOwner {
        WITHDRAWAL_FEE_FREE_PERIOD = _period;
    }

    function setFeeMax(uint _feeMax) external onlyOwner {
        FEE_MAX = _feeMax;
    }

    function setMinter(address minter, bool canMint) external override onlyOwner {
        if (canMint) {
            _minters[minter] = canMint;
        } else {
            delete _minters[minter];
        }
    }

    function setHammyPerProfitBNB(uint _ratio) external onlyOwner {
        hammyPerProfitBNB = _ratio;
    }

    function setHammyPerHammyBNBFlip(uint _hammyPerHammyBNBFlip) external onlyOwner {
        hammyPerHammyBNBFlip = _hammyPerHammyBNBFlip;
    }

    function isMinter(address account) override view public returns(bool) {
        if (HAMMY.getOwner() != address(this)) {
            return false;
        }

        return _minters[account];
    }

    function amountHammyToMint(uint bnbProfit) override view public returns(uint) {
        return bnbProfit.mul(hammyPerProfitBNB).div(1e18);
    }

    function amountHammyToMintForHammyBNB(uint amount, uint duration) override view public returns(uint) {
        return amount.mul(hammyPerHammyBNBFlip).mul(duration).div(365 days).div(1e18);
    }

    function withdrawalFee(uint amount, uint depositedAt) override view external returns(uint) {
        if (depositedAt.add(WITHDRAWAL_FEE_FREE_PERIOD) > block.timestamp) {
            return amount.mul(WITHDRAWAL_FEE).div(FEE_MAX);
        }
        return 0;
    }

    function performanceFee(uint profit) override view public returns(uint) {
        return profit.mul(PERFORMANCE_FEE).div(FEE_MAX);
    }

    function mintFor(address flip, uint _withdrawalFee, uint _performanceFee, address to, uint) override external onlyMinter {
        uint feeSum = _performanceFee.add(_withdrawalFee);
        IBEP20(flip).safeTransferFrom(msg.sender, address(this), feeSum);

        // buy back and burn
        HAMMY.safeTransfer(DEAD, tokenToHammy(flip, feeSum));

        // avoid manipulation
        (uint valueInBNB,) = CALCULATOR.valueOfAsset(flip, _performanceFee);
        uint mintHammy = amountHammyToMint(valueInBNB);

        if (mintHammy > 0) {
            _mint(mintHammy, to);
        }
    }

    function mintForHammyBNB(uint amount, uint duration, address to) override external onlyMinter {
        uint mintHammy = amountHammyToMintForHammyBNB(amount, duration);
        if (mintHammy == 0) return;
        _mint(mintHammy, to);
    }

    function mint(uint amount) external override onlyMinter {
        if (amount == 0) return;
        _mint(amount, address(this));
    }

    function safeHammyTransfer(address _to, uint _amount) external override onlyMinter {
        if (_amount == 0) return;

        uint bal = HAMMY.balanceOf(address(this));
        if (_amount <= bal) {
            HAMMY.safeTransfer(_to, _amount);
        } else {
            HAMMY.safeTransfer(_to, bal);
        }
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _mint(uint amount, address to) private {
        BEP20 hammyToken = BEP20(address(HAMMY));

        hammyToken.mint(amount);
        if (to != address(this)) {
            hammyToken.transfer(to, amount);
        }

        uint hammyForDev = amount.mul(12).div(100);
        hammyToken.mint(hammyForDev);
        REWARD_POOL.depositTo(hammyForDev, DEV);
    }
}

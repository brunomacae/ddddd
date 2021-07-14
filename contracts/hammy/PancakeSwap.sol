// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeRouter.sol";
import "../interfaces/IPancakeFactory.sol";

abstract contract PancakeSwap is OwnableUpgradeable {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    IPancakeRouter  private constant ROUTER  = IPancakeRouter(address(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakeFactory private constant FACTORY = IPancakeFactory(address(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73));

    address private constant wbnb  = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant cake  = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address private constant hammy = 0x3dA288A6BBdD8f1FD155887EECf222D9aa8B8f3d;

    function __PancakeSwap_init() internal initializer {
        __Ownable_init();
    }

    function tokenToHammy(address token, uint amount) internal returns(uint hammyAmount) {
        if (token == cake) {
            hammyAmount = _cakeToHammy(amount);
        } else {
            hammyAmount = _flipToHammy(token, amount);
        }
    }

    function _cakeToHammy(uint amount) private returns(uint hammyAmount) {
        uint256 hammyBefore = IBEP20(hammy).balanceOf(address(this));
        swapToken(cake, amount, hammy);
        hammyAmount = IBEP20(hammy).balanceOf(address(this)).sub(hammyBefore);
    }

    function _flipToHammy(address token, uint amount) private returns (uint hammyAmount) {
        IPancakePair pair = IPancakePair(token);
        address _token0 = pair.token0();
        address _token1 = pair.token1();

        // snapshot balance before remove liquidity
        uint256 _token0BeforeRemove = IBEP20(_token0).balanceOf(address(this));
        uint256 _token1BeforeRemove = IBEP20(_token1).balanceOf(address(this));

        IBEP20(token).safeApprove(address(ROUTER), 0);
        IBEP20(token).safeApprove(address(ROUTER), amount);

        ROUTER.removeLiquidity(_token0, _token1, amount, 0, 0, address(this), block.timestamp);

        uint256 hammyBefore = IBEP20(hammy).balanceOf(address(this));
        uint256 token0Amount = IBEP20(_token0).balanceOf(address(this)).sub(_token0BeforeRemove);
        uint256 token1Amount = IBEP20(_token1).balanceOf(address(this)).sub(_token1BeforeRemove);

        swapToken(_token0, token0Amount, hammy);
        swapToken(_token1, token1Amount, hammy);

        hammyAmount = IBEP20(hammy).balanceOf(address(this)).sub(hammyBefore);
    }

    function swapToken(address _from, uint _amount, address _to) private {
        if (_from == _to) return;

        address[] memory path;
        if (_from == wbnb || _to == wbnb) {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            path = new address[](3);
            path[0] = _from;
            path[1] = wbnb;
            path[2] = _to;
        }

        IBEP20(_from).safeApprove(address(ROUTER), 0);
        IBEP20(_from).safeApprove(address(ROUTER), _amount);
        ROUTER.swapExactTokensForTokens(_amount, 0, path, address(this), block.timestamp);
    }
}

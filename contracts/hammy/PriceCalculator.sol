// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPriceCalculator.sol";
import "../interfaces/AggregatorV3Interface.sol";

contract PriceCalculator is IPriceCalculator, OwnableUpgradeable {
    using SafeMath for uint;

    address private constant WBNB   = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant CAKE   = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address private constant HAMMY  = 0x3dA288A6BBdD8f1FD155887EECf222D9aa8B8f3d;

    IPancakeFactory private FACTORY = IPancakeFactory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);

    mapping(address => address) public priceFeeds;

    function initialize() external initializer {
        __Ownable_init();

        // add ChainLink price feeds
        setPriceFeed(WBNB, address(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE));
        setPriceFeed(CAKE, address(0xB6064eD41d4f67e353768aA239cA86f4F73665a1));
    }

    // get token price to in BNB
    function tokenPriceInBNB(address _token) public view returns(uint) {
        if (_token == CAKE) {
            return cakePriceInBNB();
        } else if (_token == WBNB) {
            return 1e18;
        } else {
            return unsafeTokenPriceInBNB(_token);
        }
    }

    function unsafeTokenPriceInBNB(address _token) private view returns(uint) {
        address pair = FACTORY.getPair(_token, WBNB);
        uint decimal = uint(BEP20(_token).decimals());

        (uint reserve0, uint reserve1, ) = IPancakePair(pair).getReserves();
        if (IPancakePair(pair).token0() == _token) {
            return reserve1.mul(10**decimal).div(reserve0);
        } else if (IPancakePair(pair).token1() == _token) {
            return reserve0.mul(10**decimal).div(reserve1);
        } else {
            return 0;
        }
    }

    function cakePriceInUSD() view public returns(uint) {
        (, int price, , ,) = AggregatorV3Interface(priceFeeds[CAKE]).latestRoundData();
        return uint(price).mul(1e10);
    }

    function cakePriceInBNB() view public returns(uint) {
        return cakePriceInUSD().mul(1e18).div(bnbPriceInUSD());
    }

    function bnbPriceInUSD() view public returns(uint) {
        (, int price, , ,) = AggregatorV3Interface(priceFeeds[WBNB]).latestRoundData();
        return uint(price).mul(1e10);
    }

    function valueOfAsset(address asset, uint amount) override external view returns (uint valueInBNB, uint valueInUSD) {
        if (asset == WBNB) {
            valueInBNB = amount;
            valueInUSD = bnbPriceInUSD().mul(amount).div(1e18);
        } else {
            valueInBNB = cakePriceInBNB().mul(amount).div(1e18);
            valueInUSD = cakePriceInUSD().mul(amount).div(1e18);
        }
    }

    function setPriceFeed(address asset, address addr) public onlyOwner {
        priceFeeds[asset] = addr;
    }
}

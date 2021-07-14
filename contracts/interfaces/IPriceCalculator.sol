// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IPriceCalculator {
    function valueOfAsset(address asset, uint amount) external view returns (uint valueInBNB, uint valueInUSD);
}

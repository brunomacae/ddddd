// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";

contract HammyAirdrop is Ownable {
    uint public START_TIME; // start time
    uint public AMOUNT_PER_ADDRESS = 1e17; // 0.1 HAMMY / address
    IBEP20 public HAMMY;

    mapping (address => bool) public claimStatus;

    event Claimed(address indexed account, uint256 indexed amount);

    constructor(IBEP20 hammy, uint start, uint amount) public {
        HAMMY = hammy;
        START_TIME = start;
        AMOUNT_PER_ADDRESS = amount;
    }

    modifier claimable() {
        require(block.timestamp > START_TIME, "not started");
        require(HAMMY.balanceOf(address(this)) >= AMOUNT_PER_ADDRESS, "sold out");
        require(!claimStatus[msg.sender], "already claimed!");
        _;
    }

    function available(address account) external view returns (uint) {
        if (block.timestamp <= START_TIME) return 0;

        if (HAMMY.balanceOf(address(this)) < AMOUNT_PER_ADDRESS) return 0;

        if (claimStatus[account]) return 0;

        return AMOUNT_PER_ADDRESS;
    }

    function claim() external claimable {
        HAMMY.transfer(msg.sender, AMOUNT_PER_ADDRESS);

        claimStatus[msg.sender] = true;

        emit Claimed(msg.sender, AMOUNT_PER_ADDRESS);
    }
}

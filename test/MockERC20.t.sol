// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MockERC20.sol";

contract MockERC20Test is Test {
    MockERC20 stableCoin;
    address user1 = address(1);

    function setUp() external {
        stableCoin = new MockERC20("Mock Stable Coin", "MSC", 1_000_000 ether);
        stableCoin.transfer(user1, 10_000 ether);
    }
    //test the total supply of the mock ERC20 token     
    function testInitialSupply() external view{
        uint256 totalSupply = stableCoin.totalSupply();
        assertEq(totalSupply, 1_000_000 ether);
    }
    //test the balance of user1 after transfer
    function testTransferWorks() external view {
        uint256 user1Balance = stableCoin.balanceOf(user1);
        assertEq(user1Balance, 10_000 ether);
    }

    //test approve and transferFrom functions
    function testApproveAndTransferFrom() external {
        stableCoin.mint(address(this), 5_000 ether);
        vm.prank(user1);

        stableCoin.approve(address(this), 5_000 ether);

        stableCoin.transferFrom(user1, address(2), 5_000 ether);

        assertEq(stableCoin.balanceOf(address(2)), 5_000 ether);
    }
}
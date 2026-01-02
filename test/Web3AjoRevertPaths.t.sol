// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Web3Ajo.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract Web3AjoRevertPaths is Test {
    Web3Ajo web3Ajo;
    MockERC20 stableCoin;

    address owner = address(1);
    address member1 = address(2);
    address member2 = address(3);
    address member3 = address(4);
    address stranger = address(6);

    function setUp() external {
        stableCoin = new MockERC20("Mock Stable Coin", "MSC", 1_000_000 ether);
        vm.prank(owner);
        web3Ajo = new Web3Ajo(
            address(stableCoin),
            100 ether,
            1 days,
            3,
            7 days
        );

        // Fund members with stable coins
        stableCoin.mint(member1, 500 ether);
        stableCoin.mint(member2, 500 ether);
        stableCoin.mint(member3, 500 ether);
        // assertEq(web3Ajo.owner(), owner);
    }
    //Tests for revert paths
    function testJoinTwiceReverts() external {
        vm.prank(member1);
        web3Ajo.joinCircle();

        //second join should revert
        vm.prank(member1);
        vm.expectRevert(Web3Ajo.AlreadyMember.selector);
        web3Ajo.joinCircle();
    }
    //test non-member trying to choose number
    function testNonMemberChooseNumberReverts() external {
        vm.prank(stranger);
        vm.expectRevert(Web3Ajo.NotMember.selector);
        web3Ajo.chooseNumber(1);
    }
    //test member choosing number twice
    function testMemberChooseNumberTwiceReverts() external {
        _approveAll();
        _joinAll();
        _chooseNumbers();

        //member1 tries to choose number again
        vm.prank(member1);
        vm.expectRevert(Web3Ajo.NumberAlreadyTaken.selector);
        web3Ajo.chooseNumber(1);
    }
    // test choosing a number out of range
    function testChooseNumberOutOfRangeReverts() external {
        _approveAll();
        _joinAll(); 

        //member2 tries to choose invalid number 99
        vm.prank(member2);
        vm.expectRevert(Web3Ajo.NumberAlreadyTaken.selector);
        web3Ajo.chooseNumber(99);
    }
    //test activate circle without all numbers chosen
    function testActivateCircleWithoutAllNumbersChosenReverts() external {
        _approveAll();
        _joinAll();

        //only member1 and member2 choose numbers
        vm.prank(owner);
        vm.expectRevert(Web3Ajo.NotAllNumbersChosen.selector);
        web3Ajo.activateCircle();
    }
    //test contribute before activation
    function testContributeBeforeActivationReverts() external {
        _approveAll();
        _joinAll();
        _chooseNumbers();

        //member1 tries to contribute before activation
        vm.prank(member1);
        vm.expectRevert(Web3Ajo.CircleNotActive.selector);
        web3Ajo.contribute();
    }
    function testExecutePayoutBeforeActivationReverts() external {
        _approveAll();
        _joinAll();
        _chooseNumbers();

        //owner tries to execute payout before activation
        vm.prank(owner);
        vm.expectRevert(Web3Ajo.CircleNotActive.selector);
        web3Ajo.executePayout();
    }

    function testNonOwnerActivateCircleReverts() external {
        _approveAll();
        _joinAll();
        _chooseNumbers();

        //stranger tries to activate circle
        vm.prank(stranger);
        vm.expectRevert(Web3Ajo.NotOwner.selector);
        web3Ajo.activateCircle();
    }
    //test executePayout before round complete
    function testExecutePayoutBeforeRoundCompleteReverts() external {
        _fullSetup();
        vm.prank(member1);
        web3Ajo.contribute();
        
        vm.prank(owner);
        vm.expectRevert(Web3Ajo.RoundNotComplete.selector);
        web3Ajo.executePayout();
    }
    //test triggerDefault before deadline
    function testTriggerDefaultBeforeDeadline() external {
       _fullSetup();
        vm.prank(owner);
       vm.expectRevert(Web3Ajo.ContributionStillOpen.selector);
       web3Ajo.triggerDefault(member3);
    }

    //test triggerDefault on non member
    function testTriggerDefaultOnNonMember() external {
       _fullSetup();

       vm.warp(block.timestamp + 8 days); //move past contribution deadline

        vm.prank(owner);
       vm.expectRevert(Web3Ajo.NotMember.selector);
       web3Ajo.triggerDefault(stranger);
    }

    //test cannot contribute twice in same round
    function testContributeTwiceInSameRoundReverts() external {
        _fullSetup();
        vm.prank(member1);
        web3Ajo.contribute();

        vm.prank(member1);
        vm.expectRevert(Web3Ajo.ContributionAlreadyMade.selector);
        web3Ajo.contribute();
    }

    //test triggerDefault on member who already contributed
    function testTriggerDefaultOnMemberWhoContributedReverts() external {
         _fullSetup();
          vm.prank(member2);
          web3Ajo.contribute();
    
         vm.warp(block.timestamp + 8 days); //move past contribution deadline
    
          vm.prank(owner);
         vm.expectRevert(Web3Ajo.ContributionAlreadyMade.selector);
         web3Ajo.triggerDefault(member2);
    }
    //test defaulted member cannot be defaulted again
    function testDefaultedMemberCannotBeDefaultedAgainReverts() external {
         _fullSetup();
          vm.warp(block.timestamp + 8 days); //move past contribution deadline
        web3Ajo.triggerDefault(member3);
    
          vm.prank(owner);
         vm.expectRevert(Web3Ajo.MemberDefaulted.selector);
         web3Ajo.triggerDefault(member3);
    }

    
    

    //test that triggerDefault updates state correctly
    function testTriggerDefaultUpdatesStateCorrectly() external {
        _fullSetup();
        vm.warp(block.timestamp + 8 days); //move past contribution deadline
        web3Ajo.triggerDefault(member2);

        assertTrue(web3Ajo.hasDefaulted(member2));
        assertEq(web3Ajo.defaultCountThisRound(web3Ajo.currentRound()), 1);
        assertEq(web3Ajo.activeMembersThisRound(web3Ajo.currentRound()), 2);
    }
    //test withdraw with zero balance
    function testWithdrawWithZeroBalanceReverts() external {
        _fullSetup();
        vm.prank(member1);
        vm.expectRevert(Web3Ajo.WithdrawalNotAllowed.selector);
        web3Ajo.withdrawPayout();
    }

    //test double withdraw
    // function testDoubleWithdrawReverts() external {
    //     _fullSetup();
    //     _defaultMember(member3);
    //     // vm.prank(owner);
    //     // web3Ajo.executePayout();

    //     vm.prank(member3);
    //     web3Ajo.withdrawPayout();

    //     vm.prank(member3);
    //     vm.expectRevert(Web3Ajo.AlreadyWithdrawn.selector);
    //     web3Ajo.withdrawPayout();
    // }
    
    //test that non-defaulted cannot withdraw before completion
    function testNonDefaultedCannotWithdrawBeforeCompletionReverts() external {
        _fullSetup();

        vm.prank(member1);
        vm.expectRevert(Web3Ajo.WithdrawalNotAllowed.selector);
        web3Ajo.withdrawPayout();
    }

    //test that defaulted member can withdraw before completion
    


    //Helper Functions
    function _approveAll() internal {
        vm.prank(member1);
        stableCoin.approve(address(web3Ajo), type(uint256).max);

        vm.prank(member2);
        stableCoin.approve(address(web3Ajo), type(uint256).max);

        vm.prank(member3);
        stableCoin.approve(address(web3Ajo), type(uint256).max);
    }

    function _joinAll() internal {
        vm.prank(member1);
        web3Ajo.joinCircle();

        vm.prank(member2);
        web3Ajo.joinCircle();

        vm.prank(member3);
        web3Ajo.joinCircle();
    }

    function _chooseNumbers() internal {
        vm.prank(member1);
        web3Ajo.chooseNumber(1);

        vm.prank(member2);
        web3Ajo.chooseNumber(2);

        vm.prank(member3);
        web3Ajo.chooseNumber(3);
    }

    function _fullSetup() internal {
        _approveAll();
        _joinAll();
        _chooseNumbers();

        vm.prank(owner);
        web3Ajo.activateCircle();
    }
    function _defaultMember(address member) internal {
        vm.warp(block.timestamp + 8 days); //move past contribution deadline
        vm.prank(owner);
        web3Ajo.triggerDefault(member);
    }
}
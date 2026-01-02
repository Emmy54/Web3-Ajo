// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import "../src/Web3Ajo.sol";

contract AjoTest is Test {
    Web3Ajo ajo;
    MockERC20 stableCoin;

    address owner = address(0x1);
    address member1 = address(0x2);
    address member2 = address(0x3);
    address member3 = address(0x4);

    uint256 constant CONTRIBUTION_AMOUNT = 100 * 10 ** 18; // 100 tokens
    uint256 constant CONTRIBUTION_INTERVAL = 1 days;
    uint256 constant MEMBERS = 3;
    uint256 constant ROUND_DURATION = 1 days;

    function setUp() public {
        // Deploy Mock ERC20 token
        stableCoin = new MockERC20();
        // Deploy Ajo contract
        ajo = new Web3Ajo(address(stableCoin), CONTRIBUTION_AMOUNT, CONTRIBUTION_INTERVAL, MEMBERS, ROUND_DURATION);

        // Mint tokens to members
        stableCoin.mint(member1, 1000 * 10 ** 18);
        stableCoin.mint(member2, 1000 * 10 ** 18);
        stableCoin.mint(member3, 1000 * 10 ** 18);

        //approvals
        vm.prank(member1);
        stableCoin.approve(address(ajo), type(uint256).max);

        vm.prank(member2);
        stableCoin.approve(address(ajo), type(uint256).max);

        vm.prank(member3);
        stableCoin.approve(address(ajo), type(uint256).max);
    }

    function testMembersCanJoinCircle() public {
        vm.prank(member1);
        ajo.joinCircle();

        vm.prank(member2);
        ajo.joinCircle();

        vm.prank(member3);
        ajo.joinCircle();

        assert(ajo.isMember(member1));
        assert(ajo.isMember(member2));
        assert(ajo.isMember(member3));
    }

    function testCannotJoinMoreThanMaxMembers() public {
        vm.prank(member1);
        ajo.joinCircle();

        vm.prank(member2);
        ajo.joinCircle();

        vm.prank(member3);
        ajo.joinCircle();

        address extraMember = address(0x5);
        vm.prank(extraMember);
        vm.expectRevert(Web3Ajo.CircleNotJoinable.selector);
        ajo.joinCircle();
    }

    function testMembersCanChooseNumber() public {
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        assertEq(ajo.memberToNumber(member1), 1);
        assertEq(ajo.memberToNumber(member2), 2);
        assertEq(ajo.memberToNumber(member3), 3);
    }

    function testCannotChooseTakenNumber() public {
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        vm.expectRevert(Web3Ajo.NumberAlreadyTaken.selector);
        ajo.chooseNumber(1);
    }

    function testCannotChooseNumberOutOfRange() public {
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        vm.expectRevert(Web3Ajo.NumberAlreadyTaken.selector);
        ajo.chooseNumber(0);

        vm.prank(member1);
        vm.expectRevert(Web3Ajo.NumberAlreadyTaken.selector);
        ajo.chooseNumber(MEMBERS + 1);
    }

    function testCannotChooseNumberTwice() public {
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member1);
        vm.expectRevert(Web3Ajo.NumberAlreadyTaken.selector);
        ajo.chooseNumber(2);
    }

    function testOnlyMembersCanChooseNumber() public {
        address nonMember = address(0x6);
        vm.prank(nonMember);
        vm.expectRevert(Web3Ajo.NotMember.selector);
        ajo.chooseNumber(1);
    }

    // function testOnlyMembersCanJoinCircle() public {
    //     vm.prank(owner);
    //     ajo.joinCircle(); // Owner is not a member yet

    //     assert(!ajo.isMember(owner));
    // }

    function testActivateCircle() public {
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        // Activate circle as the deploying test contract (owner)
        ajo.activateCircle();

        assertEq(uint256(ajo.circleState()), uint256(Web3Ajo.CircleState.ACTIVE));
        assertEq(ajo.currentRound(), 1);
        assertEq(ajo.totalRounds(), MEMBERS);
        assert(ajo.circleStartTime() > 0);
    }
    function testCannotActivateCircleIfNotAllNumbersChosen() public {
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        // member2 does not choose a number

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        // Attempt to activate circle as the deploying test contract (owner)
        vm.expectRevert(Web3Ajo.NotAllNumbersChosen.selector);
        ajo.activateCircle();
    }

    function testCannotActivateCircleIfNotAllMembersJoined() public {
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        // member3 does not join

        // Attempt to activate circle as the deploying test contract (owner)
        vm.expectRevert(Web3Ajo.NotAllNumbersChosen.selector);
        ajo.activateCircle();
    }

   function testRound1Contributions() public {
        // Setup: activate circle first
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        // Now test contributions
        vm.prank(member1);
        ajo.contribute();

        vm.prank(member2);
        ajo.contribute();

        vm.prank(member3);
        ajo.contribute();

        assertEq(ajo.contributionsCountThisRound(1), MEMBERS);
    }

    function testRound1Payout() public {
        // Setup: activate circle and make contributions
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        vm.prank(member1);
        ajo.contribute();
        vm.prank(member2);
        ajo.contribute();
        vm.prank(member3);
        ajo.contribute();

        // Now test payout
        address payoutMember = ajo.numberToMember(1);
        uint256 initialBalance = stableCoin.balanceOf(payoutMember);

        ajo.executePayout();

        uint256 finalBalance = stableCoin.balanceOf(payoutMember);
        assertEq(finalBalance - initialBalance, CONTRIBUTION_AMOUNT * MEMBERS);
    }

    function testCannotContributeTwiceInSameRound() public {
        // Setup: activate circle first
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        // Member1 contributes
        vm.prank(member1);
        ajo.contribute();

        // Member1 tries to contribute again in the same round
        vm.prank(member1);
        vm.expectRevert(Web3Ajo.ContributionAlreadyMade.selector);
        ajo.contribute();
    }

    function testRound2Contributions() public {
        // Setup: activate circle and complete round 1
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        vm.prank(member1);
        ajo.contribute();
        vm.prank(member2);
        ajo.contribute();
        vm.prank(member3);
        ajo.contribute();

        ajo.executePayout();

        // Advance time to next contribution interval
        vm.warp(block.timestamp + 1);

        // Now test round 2 contributions
        vm.prank(member1);
        ajo.contribute();

        vm.prank(member2);
        ajo.contribute();

        vm.prank(member3);
        ajo.contribute();

        assertEq(ajo.contributionsCountThisRound(2), MEMBERS);
    }

    function testRound2Payout() public {
        // Setup: activate circle and complete round 1
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        vm.prank(member1);
        ajo.contribute();
        vm.prank(member2);
        ajo.contribute();
        vm.prank(member3);
        ajo.contribute();

        ajo.executePayout();

        // Advance time to next contribution interval
        vm.warp(block.timestamp + 1);

        // Round 2 contributions
        vm.prank(member1);
        ajo.contribute();
        vm.prank(member2);
        ajo.contribute();
        vm.prank(member3);
        ajo.contribute();

        // Now test round 2 payout
        address payoutMember = ajo.numberToMember(2);
        uint256 initialBalance = stableCoin.balanceOf(payoutMember);

        ajo.executePayout();

        uint256 finalBalance = stableCoin.balanceOf(payoutMember);
        assertEq(finalBalance - initialBalance, CONTRIBUTION_AMOUNT * MEMBERS);
    }

    function testContributionFailsAfterDeadline() public {
        // Setup: activate circle first
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        // Advance time beyond round duration
        vm.warp(block.timestamp + ROUND_DURATION + 1);

        // Member1 tries to contribute after deadline
        vm.prank(member1);
        vm.expectRevert(Web3Ajo.ContributionClosed.selector);
        ajo.contribute();
    }

    function testMemberDefaultIfTheyMissContribution() public {
        // Setup: activate circle first
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        //Only member2 and member3 contribute
        vm.prank(member2);
        ajo.contribute();
        vm.prank(member3);
        ajo.contribute();

        // Advance time beyond round duration
        vm.warp(block.timestamp + ROUND_DURATION + 1);

        // Trigger default for member1
        ajo.triggerDefault(member1);

       assert(ajo.hasDefaulted(member1));
    }

    function testDefaultMemberCannotContributeAgain() public {
        // Setup: activate circle first
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        //Only member2 and member3 contribute
        vm.prank(member2);
        ajo.contribute();
        vm.prank(member3);
        ajo.contribute();

        // Advance time beyond round duration
        vm.warp(block.timestamp + ROUND_DURATION + 1);

        // Trigger default for member1
        ajo.triggerDefault(member1);

        // Member1 tries to contribute again
        vm.prank(member1);
        vm.expectRevert(Web3Ajo.MemberDefaulted.selector);
        ajo.contribute();
    }

    function testCannotTriggerDefaultBeforeDeadline() public {
        // Setup: activate circle first
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        // Member1 tries to trigger default before deadline
        vm.prank(member1);
        vm.expectRevert(Web3Ajo.ContributionStillOpen.selector);
        ajo.triggerDefault(member1);
    }
    function testCannotDefaultContributor() public {
        // Setup: activate circle first
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        // Member1 contributes
        vm.prank(member1);
        ajo.contribute();

        // Advance time beyond round duration
        vm.warp(block.timestamp + ROUND_DURATION + 1);

        // Try to trigger default for member1 who has contributed
        vm.expectRevert(Web3Ajo.ContributionAlreadyMade.selector);
        ajo.triggerDefault(member1);
    }

    function testNonMemberCannotContribute() public {
        address nonMember = address(0x6);
        vm.prank(nonMember);
        vm.expectRevert(Web3Ajo.NotMember.selector);
        ajo.contribute();
    }

    function testNonMemberCannotTriggerDefault() external {

        address nonMember = address(0x6);
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        // Advance time beyond round duration
        vm.prank(nonMember);
        vm.warp(block.timestamp + ROUND_DURATION + 1);
        vm.expectRevert(Web3Ajo.NotMember.selector);
        ajo.triggerDefault(nonMember);
    }
    function testCircleCompletesAfterAllRounds() public {
        // Setup: activate circle and complete all rounds
        vm.prank(member1);
        ajo.joinCircle();
        vm.prank(member1);
        ajo.chooseNumber(1);

        vm.prank(member2);
        ajo.joinCircle();
        vm.prank(member2);
        ajo.chooseNumber(2);

        vm.prank(member3);
        ajo.joinCircle();
        vm.prank(member3);
        ajo.chooseNumber(3);

        ajo.activateCircle();

        // Complete all rounds
        for (uint256 round = 1; round <= MEMBERS; round++) {
            vm.prank(member1);
            ajo.contribute();
            vm.prank(member2);
            ajo.contribute();
            vm.prank(member3);
            ajo.contribute();

            ajo.executePayout();

            // Advance time to next contribution interval
            vm.warp(block.timestamp + 1);
        }

        assertEq(uint256(ajo.circleState()), uint256(Web3Ajo.CircleState.COMPLETED));
    }

    // function testDefaultedMemberCanWithdrawBeforeCompletion() external {
    //     // Setup: activate circle first
    //     vm.prank(member1);
    //     ajo.joinCircle();
    //     vm.prank(member1);
    //     ajo.chooseNumber(1);

    //     vm.prank(member2);
    //     ajo.joinCircle();
    //     vm.prank(member2);
    //     ajo.chooseNumber(2);

    //     vm.prank(member3);
    //     ajo.joinCircle();
    //     vm.prank(member3);
    //     ajo.chooseNumber(3);

    //     ajo.activateCircle();

    //     //Only member2 and member3 contribute
    //     vm.prank(member2);
    //     ajo.contribute();
    //     vm.prank(member3);
    //     ajo.contribute();

    //     // Advance time beyond round duration
    //     vm.warp(block.timestamp + ROUND_DURATION + 1);

    //     // Trigger default for member1
    //     ajo.triggerDefault(member1);

    //     // Defaulted member1 withdraws payout
    //     uint256 initialBalance = stableCoin.balanceOf(member1);
    //     vm.prank(member1);
    //     ajo.withdrawPayout();
    //     uint256 finalBalance = stableCoin.balanceOf(member1);

    //     assertEq(finalBalance - initialBalance, CONTRIBUTION_AMOUNT * MEMBERS);
    // }
}

// Mock ERC20 Token for testing
contract MockERC20 is IERC20 {
    string public name = "Emmy Token";
    string public symbol = "EMMY";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(balanceOf[sender] >= amount, "Insufficient balance");
        require(allowance[sender][msg.sender] >= amount, "Allowance exceeded");

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        allowance[sender][msg.sender] -= amount;

        return true;
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;

        return true;
    }
}

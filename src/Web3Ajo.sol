// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
/**
 * @title Smart Contract for Web3 Ajo
 * @author Ayomide Ogunrinde
 * @notice This contract is a decentralized rotary savings Ajo(Esusu) system built on Ethereum.
 * @dev learning version
 */

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Web3Ajo {
    //Custom Errors
    error NotOwner();
    error NotMember();
    error AlreadyMember();
    error CircleNotJoinable();
    error CircleNotActive();
    error NotEnoughFunds();
    error WithdrawalNotAllowed();
    error NotAllNumbersChosen();
    error ContributionAlreadyMade();
    error ContributionStillOpen();
    error NumberAlreadyTaken();
    error RoundNotComplete();
    error AlreadyCompleted();
    error ContributionClosed();
    error MemberDefaulted();
    error InsufficientBalance();
    error NothingToWithdraw();
    error AlreadyWithdrawn();
    error WithdrawalFailed();
   


    //Events
    event memberJoined(address member);
    event numberChosen(address member, uint256 number);
    event circleStarted();
    event contributionMade(address member, uint256 amount, uint256 timestamp);
    event roundPaid(uint256 roundNumber, address recipient, uint256 amount, uint256 timestamp);
    event circleCompleted();
    event memberDefaultedEvent(address member, uint256 roundNumber);
    event Withdrawn(address indexed member, uint256 amount);

    //Enums
    enum CircleState {
        INACTIVE, //Members can join and choose numbers
        ACTIVE, //Members contribute funds and withdraw based on chosen numbers
        COMPLETED
    }

    //Storage Variables
    IERC20 public immutable i_stableCoin;
    uint256 public immutable i_contributionAmount;
    uint256 public immutable i_contributionInterval; //in seconds
    uint256 public immutable i_maxMembers;
    uint256 public currentRound;
    uint256 public roundStartTime;
    uint256 public roundDuration;
    // uint256 public contributionDeadline;
    uint256 public totalRounds;

    address public owner;
    CircleState public circleState;

    address[] public members;
    //Membership mapping
    mapping(address => bool) public isMember;
    //Number (payout order) mapping
    //number => member address
    mapping(uint256 => address) public numberToMember;
    //member address => number
    mapping(address => uint256) public memberToNumber;
    mapping(address => bool) public hasChosenNumber;
    //Contribution tracking
    mapping(address => uint256) public lastContributionTime;
    mapping(address => uint256) public totalContributed;
    // round member tracking
    mapping(uint256 => mapping(address => bool)) public hasContributedThisRound;
    mapping(uint256 => mapping(address => bool)) public hasDefaultedThisRound;
    mapping(address => bool) public hasDefaulted;
    // round => total contributions count
    mapping(uint256 => uint256) public contributionsCountThisRound;
    // round => number of active (non-defaulted) members
    mapping(uint256 => uint256) public activeMembersThisRound;
    mapping(uint256 => uint256) public defaultCountThisRound;
    //payout tracking
    mapping(address => bool) private hasWithdrawn;
    mapping(address => uint256) private WithdrawableAmount;

    uint256 public currentPayoutIndex; //Tracks whose turn it is to withdraw
    uint256 public circleStartTime;

    //Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    modifier onlyMember() {
        if (!isMember[msg.sender]) revert NotMember();
        _;
    }
    modifier onlyActiveMember() {
        if (!isMember[msg.sender]) revert NotMember();
        if (hasDefaultedThisRound[currentRound][msg.sender]) revert MemberDefaulted();
        _;
    }
    modifier inState(CircleState requiredState) {
        if (circleState != requiredState) revert CircleNotActive();
        _;
    }

    //Constructors
    constructor(address _stableCoin, uint256 _contributionAmount, uint256 _contributionInterval, uint256 _maxMembers, uint256 _roundDuration) {
        owner = msg.sender;
        i_stableCoin = IERC20(_stableCoin);
        i_contributionAmount = _contributionAmount;
        i_contributionInterval = _contributionInterval;
        i_maxMembers = _maxMembers;
        roundDuration = _roundDuration;
        roundStartTime = block.timestamp;
        circleState = CircleState.INACTIVE;

        // for (uint256 i = 0; i < _maxMembers; i++) {
        //     isMember[members[i]] = true;
        // }
    }

    //Functions
    //Member Management
    //Member joins the Ajo circle
    function joinCircle() external inState(CircleState.INACTIVE) {
        if (isMember[msg.sender]) revert AlreadyMember();
        if (members.length >= i_maxMembers) revert CircleNotJoinable();

        isMember[msg.sender] = true;
        members.push(msg.sender);

        emit memberJoined(msg.sender);
    }

    //Member chooses their payout number
    function chooseNumber(uint256 number) external onlyMember inState(CircleState.INACTIVE) {
        if (number == 0 || number > i_maxMembers) {
            revert NumberAlreadyTaken();
        }

        if (hasChosenNumber[msg.sender]) {
            revert NumberAlreadyTaken();
        }

        if (numberToMember[number] != address(0)) {
            revert NumberAlreadyTaken();
        }

        //Assign number to member
        hasChosenNumber[msg.sender] = true;
        memberToNumber[msg.sender] = number;
        numberToMember[number] = msg.sender;

        emit numberChosen(msg.sender, number);
    }

    function activateCircle() external onlyOwner inState(CircleState.INACTIVE) {
        // Ensure all members have chosen numbers
        if (members.length < i_maxMembers) {
            revert NotAllNumbersChosen();
        }
        for (uint256 i = 0; i < members.length; i++) {
            if (!hasChosenNumber[members[i]]) {
                revert NotAllNumbersChosen();
            }
        }
        circleState = CircleState.ACTIVE;
        circleStartTime = block.timestamp;
        totalRounds = i_maxMembers;
        currentRound = 1;
        roundStartTime = block.timestamp;
        activeMembersThisRound[currentRound] = i_maxMembers;

        emit circleStarted();
    }

    //Contribution and Payment Management
    function contribute() external onlyActiveMember inState(CircleState.ACTIVE) {
        
        //Deadline check
        if (block.timestamp > roundStartTime + roundDuration) {
            revert ContributionClosed();
        }
        
        if (hasContributedThisRound[currentRound][msg.sender]) {
            revert ContributionAlreadyMade();
        }
        if (hasDefaulted[msg.sender]) {
            revert MemberDefaulted();
        }

        if (circleState != CircleState.ACTIVE) {
            revert ContributionClosed();
        }

        i_stableCoin.transferFrom(msg.sender, address(this), i_contributionAmount);
        totalContributed[msg.sender] += i_contributionAmount;

        hasContributedThisRound[currentRound][msg.sender] = true;
        contributionsCountThisRound[currentRound]++;
       
    }

    function triggerDefault(address member) external  inState(CircleState.ACTIVE) {
        if (!isMember[member]) {
            revert NotMember();
        }
        if (hasContributedThisRound[currentRound][member]) {
            revert ContributionAlreadyMade();
        }
        if (block.timestamp < roundStartTime + roundDuration) {
            revert ContributionStillOpen();
        }
       
        // if (hasContributedThisRound[currentRound][member]) {
        //     revert ContributionAlreadyMade(); // Already defaulted
        //}
        if (hasDefaulted[member]) {
            revert MemberDefaulted(); // Already defaulted
        }
        hasDefaulted[member] = true;
        hasDefaultedThisRound[currentRound][member] = true;
        WithdrawableAmount[member] += i_contributionAmount; 

        activeMembersThisRound[currentRound] -= 1;
        defaultCountThisRound[currentRound] += 1; // Track default count

        emit memberDefaultedEvent(member, currentRound);
    }

    //Payout execution
    function executePayout() external inState(CircleState.ACTIVE) {
    uint256 activeMembers = activeMembersThisRound[currentRound];
    uint256 accountedMembers = contributionsCountThisRound[currentRound] + defaultCountThisRound[currentRound];
    uint256 forfietedAmount = i_contributionAmount * defaultCountThisRound[currentRound];

     // Ensure all active members have contributed or defaulted
    if (accountedMembers != i_maxMembers) {
        revert RoundNotComplete();
    }

    address recipient = numberToMember[currentRound];
    if (recipient == address(0)) revert NotMember();

    if (hasWithdrawn[recipient]) {
            revert AlreadyCompleted();
    }

    if (forfietedAmount > 0) {
        WithdrawableAmount[address(this)] += forfietedAmount;
    }

    uint256 payoutAmount = i_contributionAmount * activeMembers;
    i_stableCoin.transfer(recipient, payoutAmount);
    
    hasWithdrawn[recipient] = true;

    emit roundPaid(currentRound, recipient, payoutAmount, block.timestamp);

    if (currentRound == totalRounds) {
        circleState = CircleState.COMPLETED;
        emit circleCompleted();
    } else {
        // 🔑 advance round cleanly
        contributionsCountThisRound[currentRound] = 0;
        activeMembersThisRound[currentRound + 1] = activeMembersThisRound[currentRound] - defaultCountThisRound[currentRound];
        
        currentRound += 1;
        roundStartTime = block.timestamp;

        // 🔑 reset round accounting
        
    }
}

    //member withdraws their payout
    function withdrawPayout() external onlyMember{
        bool canWithdraw = circleState == CircleState.COMPLETED || 
        hasDefaulted[msg.sender] == true;
        //check if msg.sender has already received payout
        if (hasWithdrawn[msg.sender]) {
            revert AlreadyWithdrawn();
        }
        // check if circle is completed
        
        if (!canWithdraw) {
            revert WithdrawalNotAllowed();
        }
        uint256 refundAmount = totalContributed[msg.sender];

        if (refundAmount == 0) {
            revert NothingToWithdraw();
        }
        totalContributed[msg.sender] = 0;
        bool success = i_stableCoin.transfer(msg.sender, refundAmount);
        require (success, "Withdrawal failed");

        emit Withdrawn(msg.sender, refundAmount);
    }
}

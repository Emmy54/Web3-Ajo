// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Web3Ajo.sol";
import {MockERC20} from "../src/MockERC20.sol";

contract SimulateAjoRound is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("ANVIL_PRIVATE_KEY");

        //Anvil addresses for members
        address member1 = vm.addr(1);
        address member2 = vm.addr(2);
        address member3 = vm.addr(3);

        vm.startBroadcast();

        //Deploy Mock token 
        MockERC20 stableCoin = new MockERC20("Mock USDC", "mUSDC", 1_000_000 * 10 ** 18);

        //Fund members with mock stablecoin
        stableCoin.mint(member1, 10_000 * 10 ** 18);
        stableCoin.mint(member2, 10_000 * 10 ** 18);
        stableCoin.mint(member3, 10_000 * 10 ** 18);

        //Deploy Ajo contract
        Web3Ajo ajo = new Web3Ajo(
            address(stableCoin), // stableCoin address
            100 * 10 ** 18, // contribution amount
            1 days, // contribution interval
            3, // members
            1 days // round duration
        );
                
        vm.stopBroadcast();

        console.log("Ajo contract deployed at:", address(ajo));

        //Members approve Ajo contract and join circle
        _join(member1, ajo, stableCoin);
        _join(member2, ajo, stableCoin);
        _join(member3, ajo, stableCoin);

        //Membwers choose numbers
        _chooseNumber(member1, ajo, 1);
        _chooseNumber(member2, ajo, 2);
        _chooseNumber(member3, ajo, 3);

        //Activate circle
        vm.startBroadcast();
        ajo.activateCircle();
        vm.stopBroadcast();
        console.log("Circle activated");

        //Round 1 simulation
        _contribute(member1, ajo);
        _contribute(member2, ajo);
        _contribute(member3, ajo);

        console.log("Round 1 contributions made");

        //executePayout for round 1
        // Warp to the end of Round 1 first so the payout advances the roundStartTime
        vm.warp(block.timestamp + 1 days + 1);
        console.log("Time warped to end of Round 1");

        vm.startBroadcast();
        ajo.executePayout();
        vm.stopBroadcast();
        console.log("Round 1 payout executed");

        // //Round 2 simulation but member1 fails to contribute
        
        _contribute(member2, ajo);
        _contribute(member3, ajo);

        console.log("Round 2 contributions made but member1 missed(default)");
        //warp time to end of round 2
        vm.warp(block.timestamp + 2 days + 1);
        console.log("Time warped to end of Round 2");

        //trigger default for member1
       
        ajo.triggerDefault(member1);
        
        console.log("Default triggered for member1");
        //executePayout for round 2
        
        ajo.executePayout();
       
        console.log("Round 2 payout executed");

        //contribute() by all members
        //triggerDefault() if any member fails to contribute
        //executePayout()
    }

    //Helper fuctions
    // helper function to join Ajo circle
    function _join(address member, Web3Ajo ajo, MockERC20 stableCoin) internal {
        vm.startBroadcast(member);
        stableCoin.approve(address(ajo), type(uint256).max);
        ajo.joinCircle();
        vm.stopBroadcast();

        console.log("Member joined:", member);
    }
    // helper function to choose number
    function _chooseNumber(address member, Web3Ajo ajo, uint256 number) internal {
        vm.startBroadcast(member);
        ajo.chooseNumber(number);
        vm.stopBroadcast();

        console.log("Member chose number:", number);
    }
    // helper function to contribute
    function _contribute(address member, Web3Ajo ajo) internal {
        vm.startBroadcast(member);
        ajo.contribute();
        vm.stopBroadcast();

        console.log("Member contributed:", member);
    }
}
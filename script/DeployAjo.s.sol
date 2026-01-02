// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Web3Ajo.sol";

contract DeployAjo is Script {
    // function setUp() public {}

    function run() external{
        uint256 deployerKey = vm.envUint("ANVIL_PRIVATE_KEY");
        
        vm.startBroadcast();

        // Deploy Ajo contract
        Web3Ajo ajo = new Web3Ajo(
            address(0x1234567890123456789012345678901234567890), // stableCoin address
            100 * 10 ** 18, // contribution amount
            1 days, // contribution interval
            3, // members
            7 days // round duration
        );

        vm.stopBroadcast();
    }
}
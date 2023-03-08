// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TokyoExplorer.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPK = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPK);
        new TokyoExplorer();
        vm.stopBroadcast();
    }
}

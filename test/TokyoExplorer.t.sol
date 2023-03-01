// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TokyoExplorer.sol";

contract TokyoExplorerTest is Test {
    TokyoExplorer public tokyoExplorer;

    function setUp() public {
        tokyoExplorer = new TokyoExplorer();
    }

    function testSignatureVerification() public {
        bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
        bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
        uint8 testV = 27;

        uint256 testMap = 1;
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.prank(address(user));

        tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);

        assertEq(tokyoExplorer.unlocks(user), testMap);
    }

    function testInvalidSignatureRevert() public {
        bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
        bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
        uint8 testV = 27;

        uint256 testMap = 1;

        // not the address referenced in signature hash
        address user = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;

        vm.prank(address(user));

        vm.expectRevert(InvalidSignature.selector);
        tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);
    }

    function testUnlocks() public {
        bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
        bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
        uint8 testV = 27;

        uint256 testMap = 1;
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.prank(address(user));

        tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);

        string[] memory unlocks = tokyoExplorer.retrieveUnlocks(user);

        assertEq(unlocks.length, 1);
        assertEq(unlocks[0], tokyoExplorer.stamps(0, 2));
    }
}

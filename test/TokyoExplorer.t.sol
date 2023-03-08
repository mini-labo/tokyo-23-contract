// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/TokyoExplorer.sol";

contract TokyoExplorerTest is Test {
    TokyoExplorer public tokyoExplorer;

    event LogReceivedEther();

    receive() external payable {
        emit LogReceivedEther();
    }

    function setUp() public {
        tokyoExplorer = new TokyoExplorer();
    }

    function testMint() public {
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.deal(user, 1 ether);
        vm.startPrank(address(user));

        tokyoExplorer.mintTo{value: 0.08 ether}(user);

        vm.stopPrank();

        assertEq(address(tokyoExplorer).balance, 0.08 ether);
        assertEq(tokyoExplorer.balanceOf(user), 1);
    }

    function testWithdraw() public {
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;
        uint256 originalOwnerBalance = address(this).balance;

        vm.deal(user, 1 ether);
        vm.startPrank(address(user));

        tokyoExplorer.mintTo{value: 0.08 ether}(user);

        vm.stopPrank();

        assertEq(address(tokyoExplorer).balance, 0.08 ether);

        tokyoExplorer.withdraw();

        assertEq(address(tokyoExplorer).balance, 0 ether);
        assertEq(address(this).balance, originalOwnerBalance + 0.08 ether);
    }

    function testNonOwnerWithdrawRevert() public {
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.deal(user, 1 ether);
        vm.startPrank(address(user));

        tokyoExplorer.mintTo{value: 0.08 ether}(user);

        assertEq(address(tokyoExplorer).balance, 0.08 ether);

        vm.expectRevert();
        tokyoExplorer.withdraw();
    }

    function testSignatureVerification() public {
        bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
        bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
        uint8 testV = 27;

        uint256 testMap = 1;
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.deal(user, 1 ether);
        vm.startPrank(address(user));

        tokyoExplorer.mintTo{value: 0.08 ether}(user);
        tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);

        assertEq(tokyoExplorer.unlocks(user), testMap);

        vm.stopPrank();
    }

    function testInvalidSignatureRevert() public {
        bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
        bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
        uint8 testV = 27;

        uint256 testMap = 1;

        // not the address referenced in signature hash
        address user = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;

        vm.deal(user, 1 ether);
        vm.startPrank(user);

        tokyoExplorer.mintTo{value: 0.08 ether}(user);
        vm.expectRevert(InvalidSignature.selector);
        tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);

        vm.stopPrank();
    }

    function testNonHolderSignatureRevert() public {
        bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
        bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
        uint8 testV = 27;

        uint256 testMap = 1;

        // signature valid, but hasnt minted yet
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.prank(user);

        vm.expectRevert(NotTokenHolder.selector);
        tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);
    }

    function testUnlocks() public {
        bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
        bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
        uint8 testV = 27;

        uint256 testMap = 1;
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.deal(user, 1 ether);
        vm.startPrank(user);

        tokyoExplorer.mintTo{value: 0.08 ether}(user);
        tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);

        string[3][] memory unlocks = tokyoExplorer.retrieveUnlocks(user);

        vm.stopPrank();

        assertEq(unlocks.length, 1);
        assertEq(unlocks[0][0], tokyoExplorer.stamps(0, 0));
    }

    // PLACEHOLDER TEST
    //     function testTokenURI() public {
    //         address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;
    //
    //         vm.prank(address(user));
    //
    //         tokyoExplorer.mintTo(user);
    //
    //         console.log(tokyoExplorer.tokenURI(0));
    //
    //         assert(true);
    //     }

    // PLACEHOLDER TEST
    //     function testTokenURIWithUnlock() public {
    //         bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
    //         bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
    //         uint8 testV = 27;
    //
    //         uint256 testMap = 1;
    //         address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;
    //
    //         vm.startPrank(user);
    //
    //         tokyoExplorer.mintTo(user);
    //
    //         tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);
    //
    //         console.log(tokyoExplorer.tokenURI(0));
    //
    //         assert(true);
    //
    //         vm.stopPrank();
    //     }

    //     function testTokenURIFullUnlock() public {
    //         bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
    //         bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
    //         uint8 testV = 27;
    //
    //         uint256 testMap = 8388607;
    //
    //         address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;
    //
    //         vm.startPrank(user);
    //
    //         tokyoExplorer.mintTo(user);
    //
    //         tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);
    //
    //         console.log(tokyoExplorer.tokenURI(0));
    //
    //         assert(true);
    //
    //         vm.stopPrank();
    //     }
}

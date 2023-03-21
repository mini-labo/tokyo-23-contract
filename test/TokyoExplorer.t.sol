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

    function testTokenOf() public {
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;
        address user2 = vm.addr(1);

        vm.deal(user, 1 ether);
        vm.startPrank(address(user));

        tokyoExplorer.mintTo{value: 0.08 ether}(user);

        vm.stopPrank();

        assertEq(address(tokyoExplorer).balance, 0.08 ether);
        assertEq(tokyoExplorer.balanceOf(user), 1);
        // starting id - 1
        assertEq(tokyoExplorer.tokenOf(user), 1);
        // user has not minted - expect id 0 (unset)
        assertEq(tokyoExplorer.tokenOf(user2), 0);
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

    function testTransferRevert() public {
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;
        address recipient = vm.addr(2);

        vm.deal(user, 1 ether);
        vm.startPrank(address(user));

        tokyoExplorer.mintTo{value: 0.08 ether}(user);

        assertEq(address(tokyoExplorer).balance, 0.08 ether);

        vm.expectRevert(OnlyForYou.selector);
        tokyoExplorer.transferFrom(user, recipient, 1);
    }

    function testBurn() public {
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.deal(user, 1 ether);
        vm.startPrank(address(user));

        tokyoExplorer.mintTo{value: 0.08 ether}(user);

        assertEq(address(tokyoExplorer).balance, 0.08 ether);

        assertEq(tokyoExplorer.balanceOf(user), 1);
        tokyoExplorer.burnToken(1);
        assertEq(tokyoExplorer.balanceOf(user), 0);
    }

    function testCantBurnNonOwnedToken() public {
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.deal(user, 1 ether);
        vm.startPrank(address(user));

        tokyoExplorer.mintTo{value: 0.08 ether}(user);

        assertEq(address(tokyoExplorer).balance, 0.08 ether);

        assertEq(tokyoExplorer.balanceOf(user), 1);

        vm.stopPrank();

        vm.expectRevert();
        tokyoExplorer.burnToken(1);

        assertEq(tokyoExplorer.balanceOf(user), 1);
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

        // first id = 1
        assertEq(tokyoExplorer.unlocks(1), testMap);

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

        // first unlock id = 1
        string[3][] memory unlocks = tokyoExplorer.retrieveUnlocks(1);

        vm.stopPrank();

        assertEq(unlocks.length, 1);
        assertEq(unlocks[0][0], tokyoExplorer.stamps(0, 0));
    }

    function testUnlocksScopedToTokenId() public {
        bytes32 testR = 0x6ab633a643db3e29a88755e9ff60b388be136bcd61931f7cc092cd5b19811f2e;
        bytes32 testS = 0x38d9c000546fbe3ab80f41f48c1732550760308a4a0bf3b8e3298c9c5e97f217;
        uint8 testV = 27;

        uint256 testMap = 1;
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        vm.deal(user, 1 ether);
        vm.startPrank(user);

        tokyoExplorer.mintTo{value: 0.08 ether}(user);
        tokyoExplorer.applyUnlocks(testMap, testR, testS, testV);

        vm.stopPrank();

        address otherUser = vm.addr(2);
        vm.deal(otherUser, 1 ether);
        vm.startPrank(otherUser);
        tokyoExplorer.mintTo{value: 0.08 ether}(otherUser);

        // first unlock id = 1
        string[3][] memory firstAddrUnlocks = tokyoExplorer.retrieveUnlocks(1);
        string[3][] memory secondAddrUnlocks = tokyoExplorer.retrieveUnlocks(2);

        assertEq(firstAddrUnlocks.length, 1);
        assertEq(firstAddrUnlocks[0][0], tokyoExplorer.stamps(0, 0));

        // second addr should have no unlocks
        assertEq(secondAddrUnlocks.length, 0);
    }

    function testTokenURI() public {
        address user = 0xfa3d0C8d113f5831449a28235119A904233f9652;

        bytes memory baseSvg =
            '<svg width="600" height="600" viewBox="0 0 600 600" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="100%" height="100%" fill="#fff"/><g clip-path="url(#a)"><path d="M0 0h600v600H0z"/><path d="M333.952 416.5H263.5m-135.5-10-24 24M397.323 526l-33.497-57.689A16.693 16.693 0 0 0 349.389 460h-32.807a21.837 21.837 0 0 0-18.078 9.589v0a13.46 13.46 0 0 1-11.144 5.911h-2.406c-4.773 0-9.35-1.896-12.725-5.271l-11.113-11.113c-4.206-4.206-4.206-11.026 0-15.232v0a8.14 8.14 0 0 1 5.755-2.384h44.379" stroke="#FCD4FF" stroke-width="2" stroke-linecap="round"/><path d="m137.5 397-10 10m-6 63L104 452.5c-6.075-6.075-6.075-15.925 0-22v0m87 83.5h63.909c1.708 0 3.396.365 4.951 1.069L316 540.5l50.481 24.426a18 18 0 0 0 20.568-3.475l8.961-8.961a20 20 0 0 0 2.596-25.089L394.419 521m-88.169-79.5h40.25c6.904 0 12.5-5.596 12.5-12.5v0c0-6.904-5.596-12.5-12.5-12.5h-13.875m-83.125 0H265" stroke="#D885F8" stroke-width="8" stroke-linecap="round"/><rect x="128.5" y="447.5" width="52" height="85" rx="26"/><g clip-path="url(#b)"><rect x="141.5" y="460.5" width="26" height="59" rx="13" stroke="#FCD4FF" stroke-width="2"/></g><rect x="133.5" y="452.5" width="42" height="75" rx="21" stroke="#FCD4FF" stroke-width="2"/><path d="M336.25 405.5H286.5" stroke="#C0ACFF" stroke-width="2" stroke-linecap="round"/><path d="M249.716 405.5H287m-89.004-49.078 9.504-9.505M319 361.5h1.317c7.207 0 13.049 5.842 13.049 13.05v0a4.848 4.848 0 0 0 3.951 4.751v0c15.709 2.968 14.059 26.199-1.927 26.199h-2.89" stroke="#6651BC" stroke-width="8" stroke-linecap="round"/><rect x="190.5" y="355.5" width="52" height="85" rx="26"/><g clip-path="url(#c)"><rect x="203.5" y="368.5" width="26" height="59" rx="13" stroke="#C0ACFF" stroke-width="2"/></g><rect x="195.5" y="360.5" width="42" height="75" rx="21" stroke="#C0ACFF" stroke-width="2"/><path d="m95.5 423 26.5-26.5m27.5-71.5v-31.5" stroke="#ACF5B9" stroke-width="2" stroke-linecap="round"/><path d="m73.5 266.5-13.9 13.899a14.002 14.002 0 0 0-4.1 9.9V330.5m20.25 92.25v0c5.523 5.523 14.477 5.523 20 0l.75-.75m24-24 11.725-11.725c5.418-5.418 5.474-14.186.125-19.673l-6.014-6.168a13.506 13.506 0 0 1-3.836-9.43v0c0-7.456 6.17-13.504 13.626-13.504v0c7.318 0 13.374-5.932 13.374-13.25v0M142 284.5v0a7.5 7.5 0 0 1 7.5 7.5v6" stroke="#74D375" stroke-width="8" stroke-linecap="round"/><rect x="33.5" y="334.5" width="52" height="85" rx="26"/><g clip-path="url(#d)"><rect x="46.5" y="347.5" width="26" height="59" rx="13" stroke="#ACF5B9" stroke-width="2"/></g><rect x="38.5" y="339.5" width="42" height="75" rx="21" stroke="#ACF5B9" stroke-width="2"/><path d="M164.818 318.349v-9.25c0-5.854 4.746-10.599 10.6-10.599v0c2.839 0 5.559 1.139 7.551 3.162l16.782 17.04c5.396 5.479 5.362 14.285-.075 19.723l-2.176 2.176" stroke="#F890D5" stroke-width="2" stroke-linecap="round"/><path d="m189 308 12.644 12.644c4.326 4.326 4.292 11.351-.077 15.633L196.75 341" stroke="#D65477" stroke-width="8" stroke-linecap="round"/><circle cx="135.5" cy="350.5" r="5" fill="#D65477"/><rect x="140.5" y="330.5" width="52" height="85" rx="26"/><g clip-path="url(#e)"><rect x="153.5" y="343.5" width="26" height="59" rx="13" stroke="#F890D5" stroke-width="2"/></g><rect x="145.5" y="335.5" width="42" height="75" rx="21" stroke="#F890D5" stroke-width="2"/><path d="m287.5 266.5-5-5m66 52.5-15.567 15.567a4.892 4.892 0 0 0-1.433 3.46V339c0 6.351-5.149 11.5-11.5 11.5v0M270.5 305v-3.893A25.607 25.607 0 0 0 263 283v0" stroke="#6CB0D2" stroke-width="8" stroke-linecap="round"/><circle cx="342.5" cy="305.5" r="4" fill="#6CB0D2"/><rect x="262.5" y="306.5" width="52" height="85" rx="26"/><g clip-path="url(#f)"><rect x="275.5" y="319.5" width="26" height="59" rx="13" stroke="#A7E9F2" stroke-width="2"/></g><rect x="267.5" y="311.5" width="42" height="75" rx="21" stroke="#A7E9F2" stroke-width="2"/><path d="M194 261h15.5" stroke="#D8EA71" stroke-width="2" stroke-linecap="round"/><path d="m200.5 302.5-8.899-8.899a14 14 0 0 0-9.9-4.101H164m46.5-28.5H222" stroke="#B4CC2A" stroke-width="8" stroke-linecap="round"/><rect x="212.5" y="276.5" width="52" height="85" rx="26"/><g clip-path="url(#g)"><rect x="225.5" y="289.5" width="26" height="59" rx="13" stroke="#D8EA71" stroke-width="2"/></g><rect x="217.5" y="281.5" width="42" height="75" rx="21" stroke="#D8EA71" stroke-width="2"/><path d="M91 201.5h12.444a11 11 0 0 1 7.778 3.222L124.5 218" stroke="#A9EA86" stroke-width="2" stroke-linecap="round"/><path d="M91 201.5H66c-6.075 0-11 4.925-11 11v5.444a11 11 0 0 0 3.222 7.778l11.556 11.556A11 11 0 0 1 73 245.056v1.888a11 11 0 0 0 3.222 7.778L79 257.5m49-25v-6.757c0-2.717-1.079-5.322-3-7.243v0" stroke="#578D38" stroke-width="8" stroke-linecap="round"/><rect x="85.5" y="232.5" width="52" height="85" rx="26"/><g clip-path="url(#h)"><rect x="98.5" y="245.5" width="26" height="59" rx="13" stroke="#A9EA86" stroke-width="2"/></g><rect x="90.5" y="237.5" width="42" height="75" rx="21" stroke="#A9EA86" stroke-width="2"/><path d="m134.5 209-8.25-8.25M145 191h34" stroke="#FAC0F1" stroke-width="2" stroke-linecap="round"/><path d="m126 200.5-.875-.875c-3.935-3.935-3.935-10.315 0-14.25v0c3.935-3.935 10.315-3.935 14.25 0l1.65 1.65a13.572 13.572 0 0 0 9.597 3.975H180a9 9 0 0 1 9 9v9" stroke="#E34262" stroke-width="8" stroke-linecap="round"/><rect x="137.5" y="199.5" width="52" height="85" rx="26"/><g clip-path="url(#i)"><rect x="150.5" y="212.5" width="26" height="59" rx="13" stroke="#FAC0F1" stroke-width="2"/></g><rect x="142.5" y="204.5" width="42" height="75" rx="21" stroke="#FAC0F1" stroke-width="2"/><path d="M249.5 188.25h3.204A23.046 23.046 0 0 1 269 195v0m-68 37v-14.429a5 5 0 0 1 1.464-3.535L206.5 210" stroke="#FF9BDE" stroke-width="2" stroke-linecap="round"/><path d="M249.5 188.25h3.204A23.046 23.046 0 0 1 269 195v0m17 32v11.257c0 2.717-1.079 5.322-3 7.243v0m-61.5 3.5H215c-7.732 0-14-6.268-14-14v-3" stroke="#C32D76" stroke-width="8" stroke-linecap="round"/><circle cx="187.5" cy="179.5" r="4" fill="#C32D76"/><rect x="226.5" y="195.5" width="52" height="85" rx="26"/><g clip-path="url(#j)"><rect x="239.5" y="208.5" width="26" height="59" rx="13" stroke="#FF9BDE" stroke-width="2"/></g><rect x="231.5" y="200.5" width="42" height="75" rx="21" stroke="#FF9BDE" stroke-width="2"/><path d="M361 214v0a7.5 7.5 0 0 1-7.5-7.5v-3a1.5 1.5 0 0 0-1.5-1.5h-12.5" stroke="#8672CB" stroke-width="8" stroke-linecap="round"/><circle cx="365.5" cy="229.5" r="4" fill="#8672CB"/><rect x="292.5" y="220.5" width="52" height="85" rx="26"/><g clip-path="url(#k)"><rect x="305.5" y="233.5" width="26" height="59" rx="13" stroke="#D3C0FF" stroke-width="2"/></g><rect x="297.5" y="225.5" width="42" height="75" rx="21" stroke="#D3C0FF" stroke-width="2"/><path d="M406.5 278v20.444a11 11 0 0 1-3.222 7.778L391.5 318" stroke="#F5E35B" stroke-width="2" stroke-linecap="round"/><path d="m366 322.5.601.601c5.467 5.467 14.331 5.467 19.798 0L391.5 318m5-75 6.778 6.778a11 11 0 0 1 3.222 7.778V278" stroke="#F7DA00" stroke-width="8" stroke-linecap="round"/><rect x="344.5" y="233.5" width="52" height="85" rx="26"/><g clip-path="url(#l)"><rect x="357.5" y="246.5" width="26" height="59" rx="13" stroke="#F5E35B" stroke-width="2"/></g><rect x="349.5" y="238.5" width="42" height="75" rx="21" stroke="#F5E35B" stroke-width="2"/><path d="m473.5 259.5 1.607 1.607a14.999 14.999 0 0 1 4.393 10.606v51.519" stroke="#81E0FF" stroke-width="2" stroke-linecap="round"/><path d="M391 351.5v0c-4.971-4.971-4.971-13.029 0-18l1-1m64 34v0a7 7 0 0 0 7-7v-11.771c0-.147.058-.287.162-.391l14.874-14.874a5 5 0 0 0 1.464-3.535V319.5" stroke="#489DC3" stroke-width="8" stroke-linecap="round"/><rect x="396.5" y="306.5" width="52" height="85" rx="26"/><g clip-path="url(#m)"><rect x="409.5" y="319.5" width="26" height="59" rx="13" stroke="#81E0FF" stroke-width="2"/></g><rect x="401.5" y="311.5" width="42" height="75" rx="21" stroke="#81E0FF" stroke-width="2"/><rect x="517.5" y="225.5" width="52" height="85" rx="26"/><g clip-path="url(#n)"><rect x="530.5" y="238.5" width="26" height="59" rx="13" stroke="#99F0D7" stroke-width="2"/></g><rect x="522.5" y="230.5" width="42" height="75" rx="21" stroke="#99F0D7" stroke-width="2"/><path d="M489.444 332h2.056a7 7 0 0 1 7 7v19.5a7 7 0 0 0 7 7h6" stroke="#99F0D7" stroke-width="2" stroke-linecap="round"/><path d="M544 316.5v15.711a33.289 33.289 0 0 1-9.75 23.539v0a33.289 33.289 0 0 1-23.539 9.75H510M470 216l7.207-7.207a1 1 0 0 1 .707-.293h30.364c.123 0 .222.099.222.222v2.028c0 6.489 5.261 11.75 11.75 11.75v0c6.489 0 11.75-5.261 11.75-11.75V183.5c0-10.217 8.283-18.5 18.5-18.5v0c10.217 0 18.5 8.283 18.5 18.5v44" stroke="#90E8CF" stroke-width="8" stroke-linecap="round"/><path d="M423 202.5V172a6 6 0 0 1 6-6h12.015a6 6 0 0 1 4.242 1.757l23.5 23.5a6 6 0 0 1 0 8.486L463 205.5" stroke="#8BBEFF" stroke-width="2" stroke-linecap="round"/><path d="m463 205.5 5.757-5.757a6 6 0 0 0 0-8.486L468 190.5m-45-6.25V172a6 6 0 0 1 6-6h12.015a6 6 0 0 1 4.242 1.757L450 172.5" stroke="#3860B5" stroke-width="8" stroke-linecap="round"/><circle cx="410.5" cy="237.5" r="4" fill="#3860B5"/><rect x="414.5" y="203.5" width="52" height="85" rx="26"/><g clip-path="url(#o)"><rect x="427.5" y="216.5" width="26" height="59" rx="13" stroke="#8BBEFF" stroke-width="2"/></g><rect x="419.5" y="208.5" width="42" height="75" rx="21" stroke="#8BBEFF" stroke-width="2"/><path d="M548 115.111V88.056a11 11 0 0 0-3.222-7.778L525.5 61M458 102.5h-13.25m45.25-32v-16M449 151l17.5 17.5 11.75 11.75" stroke="#ABDF96" stroke-width="2" stroke-linecap="round"/><path d="M548 149v-37.25M507.5 192h-14.186a8 8 0 0 1-5.657-2.343l-9.407-9.407M449 151l-14.278-14.278a11 11 0 0 1-3.222-7.778V113.5c0-6.075 4.925-11 11-11h2.25m45.25-46v-8.808a9.193 9.193 0 0 1 9.192-9.192v0c2.438 0 4.776.968 6.5 2.692L525.5 61" stroke="#52BB81" stroke-width="8" stroke-linecap="round"/><rect x="464.5" y="75.5" width="52" height="85" rx="26"/><g clip-path="url(#p)"><rect x="477.5" y="88.5" width="26" height="59" rx="13" stroke="#ABDF96" stroke-width="2"/></g><rect x="469.5" y="80.5" width="42" height="75" rx="21" stroke="#ABDF96" stroke-width="2"/><path d="M115 131.5v4.5c0 5.523 4.477 10 10 10h18.5c5.523 0 10-4.477 10-10v-4.5m-64 59h9c7.18 0 12.728-6.391 17.077-12.104 3.653-4.798 9.426-7.896 15.923-7.896 13 0 15 9 19.418 9H176" stroke="#FABF8D" stroke-width="2" stroke-linecap="round"/><path d="M100 116.5h5c5.523 0 10 4.477 10 10v6.5m38.5 0v0c0-9.113 7.387-16.5 16.5-16.5h.5c9.389 0 17 7.611 17 17v34M39.5 153l-4.107 4.107A15 15 0 0 0 31 167.713v23.574a15 15 0 0 0 4.393 10.606L45 211.5m26.5-21H91m83.5-11h-11.25" stroke="#DD7508" stroke-width="8" stroke-linecap="round"/><rect x="43.5" y="96.5" width="52" height="85" rx="26"/><g clip-path="url(#q)"><rect x="56.5" y="109.5" width="26" height="59" rx="13" stroke="#FABF8D" stroke-width="2"/></g><rect x="48.5" y="101.5" width="42" height="75" rx="21" stroke="#FABF8D" stroke-width="2"/><path d="M248 130.5h1c11.046 0 20 8.954 20 20v0" stroke="#BBA46A" stroke-width="8" stroke-linecap="round"/><circle cx="198.5" cy="127.5" r="4" fill="#BBA46A"/><rect x="192.5" y="125.5" width="52" height="85" rx="26"/><g clip-path="url(#r)"><rect x="205.5" y="138.5" width="26" height="59" rx="13" stroke="#FBDCA1" stroke-width="2"/></g><rect x="197.5" y="130.5" width="42" height="75" rx="21" stroke="#FBDCA1" stroke-width="2"/><path d="M241.5 86v16.186a27.315 27.315 0 0 0 8 19.314v0" stroke="#8BE6D4" stroke-width="2" stroke-linecap="round"/><path d="M153.5 111v-1.186a27.316 27.316 0 0 1 8-19.314v0m62.5-32v0c9.665 0 17.5 7.835 17.5 17.5v12.5" stroke="#539A8E" stroke-width="8" stroke-linecap="round"/><rect x="166.5" y="31.5" width="52" height="85" rx="26"/><g clip-path="url(#s)"><rect x="179.5" y="44.5" width="26" height="59" rx="13" stroke="#8BE6D4" stroke-width="2"/></g><rect x="171.5" y="36.5" width="42" height="75" rx="21" stroke="#8BE6D4" stroke-width="2"/><path d="m305 135 .722-.722c4.296-4.296 11.26-4.296 15.556 0L322 135" stroke="#52BB81" stroke-width="8" stroke-linecap="round"/><circle cx="270.5" cy="180.5" r="4" fill="#52BB81"/><rect x="274.5" y="139.5" width="52" height="85" rx="26"/><g clip-path="url(#t)"><rect x="287.5" y="152.5" width="26" height="59" rx="13" stroke="#8CFFB2" stroke-width="2"/></g><rect x="279.5" y="144.5" width="42" height="75" rx="21" stroke="#8CFFB2" stroke-width="2"/><path d="M361.5 177.5h-11.029a12 12 0 0 0-8.486 3.515L338.5 184.5" stroke="#CD394B" stroke-width="8" stroke-linecap="round"/><path d="M335.5 193.5a4 4 0 1 1-8 0 4 4 0 0 1 8 0Zm51-44a4 4 0 1 1-8 0 4 4 0 0 1 8 0Z" fill="#CD394B"/><rect x="366.5" y="152.5" width="52" height="85" rx="26"/><g clip-path="url(#u)"><rect x="379.5" y="165.5" width="26" height="59" rx="13" stroke="#F78FAC" stroke-width="2"/></g><rect x="371.5" y="157.5" width="42" height="75" rx="21" stroke="#F78FAC" stroke-width="2"/><path d="M302 71.5h18.029a12 12 0 0 1 8.486 3.515L338.5 85" stroke="#C4D1CC" stroke-width="8" stroke-linecap="round"/><rect x="245.5" y="41.5" width="52" height="85" rx="26"/><g clip-path="url(#v)"><rect x="258.5" y="54.5" width="26" height="59" rx="13" stroke="#CCDFD8" stroke-width="2"/></g><rect x="250.5" y="46.5" width="42" height="75" rx="21" stroke="#CCDFD8" stroke-width="2"/><path d="M297.5 125.5a4 4 0 1 1-8 0 4 4 0 0 1 8 0Z" fill="#C4D1CC"/><path d="M383 125h8.882c7.797 0 14.118 6.321 14.118 14.118v0c0 .487.402.882.889.882v0c8.008 0 14.611 6.492 14.611 14.5v0" stroke="#45853A" stroke-width="8" stroke-linecap="round"/><rect x="326.5" y="86.5" width="52" height="85" rx="26"/><g clip-path="url(#w)"><rect x="339.5" y="99.5" width="26" height="59" rx="13" stroke="#90E86B" stroke-width="2"/></g><rect x="331.5" y="91.5" width="42" height="75" rx="21" stroke="#90E86B" stroke-width="2"/><path d="M436 90.5h20.036A4.964 4.964 0 0 0 461 85.536V82.1c0-6.959 5.641-12.6 12.6-12.6v0a3.9 3.9 0 0 0 3.9-3.9V48.571a5.003 5.003 0 0 0-1.464-3.535l-6.786-6.786" stroke="#FBC0FF" stroke-width="2" stroke-linecap="round"/><path d="M436 90.5h12.5m20.75-52.25-4.149-4.15a14.002 14.002 0 0 0-9.9-4.1H365c-11.598 0-21 9.402-21 21v19.015a6 6 0 0 0 1.757 4.242L355 83.5" stroke="#C557D1" stroke-width="8" stroke-linecap="round"/><rect x="375.5" y="34.5" width="52" height="85" rx="26"/><g clip-path="url(#x)"><rect x="388.5" y="47.5" width="26" height="59" rx="13" stroke="#FBC0FF" stroke-width="2"/></g><rect x="380.5" y="39.5" width="42" height="75" rx="21" stroke="#FBC0FF" stroke-width="2"/><path d="M30.5 98.735v52.305a.445.445 0 0 1-.171.351 17.87 17.87 0 0 0-6.829 14.051v27.073c0 5.565 2.21 10.903 6.146 14.839a2.91 2.91 0 0 1 .854 2.06V559a8.5 8.5 0 0 0 8.5 8.5h312.745c.759 0 1.509.157 2.204.461l10.943 4.788a20.894 20.894 0 0 0 8.373 1.751h1.88a25.395 25.395 0 0 0 16.724-6.284 2.9 2.9 0 0 1 1.907-.716h38.239a6.5 6.5 0 0 0 4.596-1.904l130.985-130.985a6.5 6.5 0 0 0 1.904-4.596v-190.56a5.454 5.454 0 0 1 2.748-4.735 8.44 8.44 0 0 0 4.252-7.327V182.2c0-6.36-2.413-12.483-6.753-17.132a.92.92 0 0 1-.247-.628V37a8.5 8.5 0 0 0-8.5-8.5h-86.941a5.5 5.5 0 0 1-3.377-1.159l-1.417-1.101a22.498 22.498 0 0 0-13.813-4.74H361.8a22.95 22.95 0 0 0-16.229 6.722.949.949 0 0 1-.671.278H100.735a6.5 6.5 0 0 0-4.596 1.904L32.404 94.139a6.5 6.5 0 0 0-1.904 4.596Z" stroke="#EB94D6"/><path d="m554.248 472.43-.17 12.061" stroke="#F5ABE1" stroke-width="6" stroke-linecap="round"/><path d="m554.078 484.491 7.135-7.135m-15.993-2.075a4.827 4.827 0 0 1-.44-2.02c0-2.651 2.128-4.8 4.754-4.8 2.363 0 4.323 1.741 4.691 4.022" stroke="#E215AC" stroke-width="6" stroke-linecap="round"/><path d="M556.118 462.246a4.053 4.053 0 0 1 .089-1.698 4.05 4.05 0 0 1 4.956-2.872 4.05 4.05 0 0 1 2.856 4.965 4.061 4.061 0 0 1-.773 1.515" stroke="#F5ABE1" stroke-width="6" stroke-linecap="round"/><path d="M565.17 471.298a4.051 4.051 0 0 0 1.698-.088 4.05 4.05 0 0 0 2.873-4.956 4.05 4.05 0 0 0-4.966-2.856 4.06 4.06 0 0 0-1.515.772" stroke="#E215AC" stroke-width="6" stroke-linecap="round"/><path d="m467.672 548.627 11.892 11.891" stroke="#F5ABE1" stroke-width="6" stroke-linecap="round"/><path d="m463.001 553.299 9.173-9.174" stroke="#E215AC" stroke-width="6" stroke-linecap="round"/><path d="m492.305 523.995 11.891 11.891m8.329-8.748-11.36-3.044" stroke="#F5ABE1" stroke-width="6" stroke-linecap="round"/><path d="M500.803 515.496v16.997" stroke="#E215AC" stroke-width="6" stroke-linecap="round"/><path d="M481.263 546.928a8.407 8.407 0 0 0 11.891 0 8.407 8.407 0 0 0 0-11.891" stroke="#F5ABE1" stroke-width="6" stroke-linecap="round"/><path d="M493.154 535.037a8.407 8.407 0 0 0-11.891 0 8.407 8.407 0 0 0 0 11.891" stroke="#E215AC" stroke-width="6" stroke-linecap="round"/><path d="m515.505 510.744 6.597 6.597.32.32m-6.917-16.527v9.61" stroke="#F5ABE1" stroke-width="6" stroke-linecap="round"/><path d="M505.895 510.744h10.077" stroke="#E215AC" stroke-width="6" stroke-linecap="round"/><rect x="519.211" y="497.615" width="26.72" height="16.441" rx="8.22" transform="rotate(-45 519.211 497.615)" stroke="#F5ABE1" stroke-width="6"/><path d="M525.052 503.4v0a8.353 8.353 0 0 1 0-11.813l7.025-7.024a8.352 8.352 0 0 1 11.812 0v0" stroke="#E215AC" stroke-width="6" stroke-linecap="round"/></g><defs><clipPath id="a"><path d="M0 0h600v600H0z"/></clipPath><clipPath id="b"><rect x="132.5" y="451.5" width="44" height="77" rx="22"/></clipPath><clipPath id="c"><rect x="194.5" y="359.5" width="44" height="77" rx="22"/></clipPath><clipPath id="d"><rect x="37.5" y="338.5" width="44" height="77" rx="22"/></clipPath><clipPath id="e"><rect x="144.5" y="334.5" width="44" height="77" rx="22"/></clipPath><clipPath id="f"><rect x="266.5" y="310.5" width="44" height="77" rx="22"/></clipPath><clipPath id="g"><rect x="216.5" y="280.5" width="44" height="77" rx="22"/></clipPath><clipPath id="h"><rect x="89.5" y="236.5" width="44" height="77" rx="22"/></clipPath><clipPath id="i"><rect x="141.5" y="203.5" width="44" height="77" rx="22"/></clipPath><clipPath id="j"><rect x="230.5" y="199.5" width="44" height="77" rx="22"/></clipPath><clipPath id="k"><rect x="296.5" y="224.5" width="44" height="77" rx="22"/></clipPath><clipPath id="l"><rect x="348.5" y="237.5" width="44" height="77" rx="22"/></clipPath><clipPath id="m"><rect x="400.5" y="310.5" width="44" height="77" rx="22"/></clipPath><clipPath id="n"><rect x="521.5" y="229.5" width="44" height="77" rx="22"/></clipPath><clipPath id="o"><rect x="418.5" y="207.5" width="44" height="77" rx="22"/></clipPath><clipPath id="p"><rect x="468.5" y="79.5" width="44" height="77" rx="22"/></clipPath><clipPath id="q"><rect x="47.5" y="100.5" width="44" height="77" rx="22"/></clipPath><clipPath id="r"><rect x="196.5" y="129.5" width="44" height="77" rx="22"/></clipPath><clipPath id="s"><rect x="170.5" y="35.5" width="44" height="77" rx="22"/></clipPath><clipPath id="t"><rect x="278.5" y="143.5" width="44" height="77" rx="22"/></clipPath><clipPath id="u"><rect x="370.5" y="156.5" width="44" height="77" rx="22"/></clipPath><clipPath id="v"><rect x="249.5" y="45.5" width="44" height="77" rx="22"/></clipPath><clipPath id="w"><rect x="330.5" y="90.5" width="44" height="77" rx="22"/></clipPath><clipPath id="x"><rect x="379.5" y="38.5" width="44" height="77" rx="22"/></clipPath></defs></svg>';

        tokyoExplorer.setBaseImage(baseSvg);

        tokyoExplorer.honoraryMint(user);

        console.log(tokyoExplorer.tokenURI(1));

        // the purpose of this test is just to log tokenURI output, for debugging purposes.
        assert(true);
    }

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

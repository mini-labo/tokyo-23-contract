// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/console.sol";

error InvalidSignature();

contract TokyoExplorer {
    /// @dev bitmap for each address representing unlocked locations
    mapping(address => uint256) public unlocks;

    /// @dev collection of image offset coordinates
    /// and stamp text for reward stamps
    string[3][23] public stamps;

    constructor() {
        stamps[0] = ["7.7", "11", unicode"渋谷"];
        stamps[1] = ["9.7", "12", "bad"];
    }

    address public immutable teamSigner = 0x489DeaF7D6aD9512a183eA01dD5331011d662a6c;

    function applyUnlocks(uint256 unlockMap, bytes32 r, bytes32 s, uint8 v) public {
        bytes memory encoded = abi.encode(msg.sender, unlockMap);
        bytes32 signatureHash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", toString(encoded.length), encoded));
        address recovered = ecrecover(signatureHash, v, r, s);

        if (recovered != teamSigner) {
            revert InvalidSignature();
        }

        unlocks[msg.sender] = unlockMap;
    }

    //     // TODO
    //     function renderImage() public view returns(string) {
    //
    //     }

    function retrieveUnlocks(address user) public view returns (string[] memory) {
        uint256 unlocked = unlocks[user];

        // determine size to be declared
        uint256 length = 0;
        for (uint256 i = 0; i < 23; i++) {
            if ((unlocked >> i) & 1 == 1) {
                console.log("unlocked at index:", i);
                length++;
            }
        }

        string[] memory output = new string[](length);

        uint256 index = 0;
        for (uint256 i = 0; i < stamps.length; i++) {
            if ((unlocked >> i) & 1 == 1) {
                output[index] = stamps[i][2];
                index++;
            }
        }

        return output;
    }

    /// @dev Returns the base 10 decimal representation of `value`.
    /// @dev credit https://github.com/Vectorized/solady/blob/main/src/utils/LibString.sol.
    function toString(uint256 value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits.
            str := add(mload(0x40), 0x80)
            // Update the free memory pointer to allocate.
            mstore(0x40, add(str, 0x20))
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            let w := not(0) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let temp := value } 1 {} {
                str := add(str, w) // `sub(str, 1)`.
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "ERC721A/ERC721A.sol";
import "solady/utils/Base64.sol";
import "solady/utils/SSTORE2.sol";
import "solady/auth/Ownable.sol";

error InvalidSignature();
error MaximumOneTokenPerAddress();
error InsufficientFunds();
error NotTokenHolder();
error OnlyForYou();

contract TokyoExplorer is ERC721A, Ownable {
    event UnlocksApplied(uint256 _tokenId, uint256 _unlocks);

    /// @dev event for third party marketplace update tracking
    event MetadataUpdate(uint256 _tokenId);

    // bitmap for each tokenId representing unlocked locations
    mapping(uint256 => uint256) public unlocks;

    // id associated with a given owner for easy access
    mapping(address => uint256) public tokenOf;

    // collection of image offset coordinates and text for reward stamps
    string[3][23] public stamps;

    uint256 public immutable cost = 0.08 ether;

    // address of the issuer for signatures verified in applyUnlocks
    address public immutable teamSigner = 0x489DeaF7D6aD9512a183eA01dD5331011d662a6c;

    // address where base svg image is stored
    address private baseSvgPointer;

    // TODO: replace these placeholder coordinates!
    // might need custom scale value as well based on character length
    constructor() ERC721A("TOKYO 23", "TOKYO23") {
        stamps[0] = ["7.7", "11", unicode"千代田"];
        stamps[1] = ["7.7", "11", unicode"中央"];
        stamps[2] = ["7.7", "11", unicode"港"];
        stamps[3] = ["7.7", "11", unicode"新宿"];
        stamps[4] = ["7.7", "11", unicode"文京"];
        stamps[5] = ["7.7", "11", unicode"台東"];
        stamps[6] = ["7.7", "11", unicode"墨田"];
        stamps[7] = ["7.7", "11", unicode"江東"];
        stamps[8] = ["7.7", "11", unicode"品川"];
        stamps[9] = ["175.2", "317.8", unicode"目黒"];
        stamps[10] = ["7.7", "11", unicode"大田"];
        stamps[11] = ["7.7", "11", unicode"世田谷"];
        stamps[12] = ["7.7", "11", unicode"渋谷"];
        stamps[13] = ["7.7", "11", unicode"中野"];
        stamps[14] = ["7.7", "11", unicode"杉並"];
        stamps[15] = ["7.7", "11", unicode"豊島"];
        stamps[16] = ["7.7", "11", unicode"北"];
        stamps[17] = ["7.7", "11", unicode"荒川"];
        stamps[18] = ["7.7", "11", unicode"板橋"];
        stamps[19] = ["7.7", "11", unicode"練馬"];
        stamps[20] = ["7.7", "11", unicode"足立"];
        stamps[21] = ["7.7", "11", unicode"葛飾"];
        stamps[22] = ["7.7", "11", unicode"江戸川"];

        _initializeOwner(msg.sender);
    }

    // start at 1, so we can treat the unset 0 value as null in the tokenOf mapping
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function setBaseImage(bytes calldata image) public onlyOwner {
        address location = SSTORE2.write(image);
        baseSvgPointer = location;
    }

    function mintTo(address to) public payable {
        if (balanceOf(to) > 0) {
            revert MaximumOneTokenPerAddress();
        }

        if (msg.value < cost) {
            revert InsufficientFunds();
        }

        tokenOf[to] = _nextTokenId();
        _mint(to, 1);
    }

    function honoraryMint(address to) public onlyOwner {
        if (balanceOf(to) > 0) {
            revert MaximumOneTokenPerAddress();
        }

        tokenOf[to] = _nextTokenId();
        _mint(to, 1);
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function burnToken(uint256 tokenId) public {
        _burn(tokenId, true);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string[3][] memory unlockedStamps = retrieveUnlocks(tokenId);
        bytes memory encodedAttributes;
        for (uint256 i = 0; i < unlockedStamps.length; i++) {
            string[3] memory stamp = unlockedStamps[i];
            if (i == 0) {
                encodedAttributes = ",";
            }

            encodedAttributes = abi.encodePacked(encodedAttributes, '{"value":"', stamp[2], '"}');
            if (i < unlockedStamps.length - 1) {
                encodedAttributes = abi.encodePacked(encodedAttributes, ",");
            }
        }

        string memory baseUrl = "data:application/json;base64,";
        return string(
            abi.encodePacked(
                baseUrl,
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"TOKYO 23",',
                            '"description":"TOKYO 23",',
                            '"attributes":[{"trait_type":"points","max_value":23,"value":',
                            _toString(unlockedStamps.length),
                            "}",
                            encodedAttributes,
                            "]," '"image":"',
                            buildSvg(unlockedStamps),
                            '"}'
                        )
                    )
                )
            )
        );
    }

    // validate a signature, applying reported unlocks if valid
    function applyUnlocks(uint256 unlockMap, bytes32 r, bytes32 s, uint8 v) public {
        if (balanceOf(msg.sender) < 1) revert NotTokenHolder();
        uint256 tokenId = tokenOf[msg.sender];

        bytes memory encoded = abi.encode(msg.sender, unlockMap);
        bytes32 signatureHash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", _toString(encoded.length), encoded));
        address recovered = ecrecover(signatureHash, v, r, s);

        if (recovered != teamSigner) {
            revert InvalidSignature();
        }

        unlocks[tokenId] = unlockMap;

        emit MetadataUpdate(tokenId);
        emit UnlocksApplied(tokenId, unlockMap);
    }

    function buildSvg(string[3][] memory unlockedStamps) internal view returns (string memory) {
        string memory baseUrl = "data:image/svg+xml;base64,";

        bytes memory encodedStamps;
        for (uint256 i = 0; i < unlockedStamps.length; i++) {
            string[3] memory stamp = unlockedStamps[i];

            bytes memory stampSvg = abi.encodePacked(
                "<g transform=\"translate(",
                abi.encodePacked(stamp[0], ",", stamp[1]),
                ") scale(1.8)\">",
                "<path xmlns=\"http://www.w3.org/2000/svg\" fill-rule=\"evenodd\" clip-rule=\"evenodd\" d=\"M20 5v14.054c0 2.303-2.488 3.747-4.488 2.604l-3.016-1.723a1 1 0 0 0-.992 0l-3.016 1.723c-2 1.143-4.488-.3-4.488-2.604V5a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3Z\" fill=\"#323232\"/>",
                "<text x=\"11.7\" y=\"3.8\" style=\"writing-mode:tb;\" font-weight=\"bold\" stroke=\"black\" font-size=\"7.2\" stroke-width=\"0.1\" fill=\"white\">",
                stamp[2],
                "</text></g>"
            );

            encodedStamps = abi.encodePacked(encodedStamps, stampSvg);
        }

        bytes memory baseSvg = SSTORE2.read(baseSvgPointer);

        return string(
            abi.encodePacked(
                baseUrl,
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            "<svg width=\"600\" height=\"600\" viewBox=\"0 0 600 600\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">",
                            baseSvg,
                            encodedStamps,
                            "</svg>"
                        )
                    )
                )
            )
        );
    }

    function retrieveUnlocks(uint256 tokenId) public view returns (string[3][] memory) {
        uint256 unlocked = unlocks[tokenId];

        // determine size to be declared
        uint256 length = 0;
        for (uint256 i = 0; i < 23; i++) {
            if ((unlocked >> i) & 1 == 1) {
                length++;
            }
        }

        string[3][] memory output = new string[3][](length);

        uint256 index = 0;
        for (uint256 i = 0; i < stamps.length; i++) {
            if ((unlocked >> i) & 1 == 1) {
                output[index] = stamps[i];
                index++;
            }
        }

        return output;
    }

    // prevent transfer (except mint and burn)
    function _beforeTokenTransfers(address from, address to, uint256, uint256) internal pure override {
        if (from != address(0) && to != address(0)) {
            revert OnlyForYou();
        }
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }
}

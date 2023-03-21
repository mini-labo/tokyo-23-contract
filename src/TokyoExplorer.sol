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
    string[5][23] public stamps;

    uint256 public immutable cost = 0.08 ether;

    // address of the issuer for signatures verified in applyUnlocks
    address public immutable teamSigner = 0x489DeaF7D6aD9512a183eA01dD5331011d662a6c;

    // address where base svg image is stored
    address private baseSvgPointer;

    constructor() ERC721A("TOKYO 23", "TOKYO23") {
        stamps[0] = ["297.5", "225.5", "8672cb", "645597", unicode"千代田"];
        stamps[1] = ["348.5", "237.5", "f7da00", "c4ad00", unicode"中央"];
        stamps[2] = ["266.5", "310.5", "6cb0d2", "51849e", unicode"港"];
        stamps[3] = ["230.5", "199.5", "c32d76", "8a2057", unicode"新宿"];
        stamps[4] = ["278.5", "143.5", "52bb81", "3a875e", unicode"文京"];
        stamps[5] = ["370.5", "156.5", "cd394b", "9c2a38", unicode"台東"];
        stamps[6] = ["418.5", "207.5", "3860b5", "274482", unicode"墨田"];
        stamps[7] = ["400.5", "310.5", "489dc3", "34728f", unicode"江東"];
        stamps[8] = ["194.5", "359.5", "6651bc", "493a87", unicode"品川"];
        stamps[9] = ["144.5", "334.5", "d65477", "a5405c", unicode"目黒"];
        stamps[10] = ["132.5", "451.5", "d885f8", "aa69c4", unicode"大田"];
        stamps[11] = ["37.5", "338.5", "74d375", "57a058", unicode"世田谷"];
        stamps[12] = ["216.5", "280.5", "b4cc2a", "879920", unicode"渋谷"];
        stamps[13] = ["141.5", "203.5", "e34262", "b2334d", unicode"中野"];
        stamps[14] = ["89.5", "236.5", "578d38", "375a23", unicode"杉並"];
        stamps[15] = ["196.5", "129.5", "bba46a", "87994d", unicode"豊島"];
        stamps[16] = ["249.5", "45.5", "c4d1cc", "949e9a", unicode"北"];
        stamps[17] = ["330.5", "90.5", "45853a", "2a5524", unicode"荒川"];
        stamps[18] = ["170.5", "35.5", "539a8e", "37665e", unicode"板橋"];
        stamps[19] = ["47.5", "100.5", "dd7508", "ac5a08", unicode"練馬"];
        stamps[20] = ["379.5", "38.5", "c557d1", "93419e", unicode"足立"];
        stamps[21] = ["468.5", "79.5", "6d9365", "475f42", unicode"葛飾"];
        stamps[22] = ["521.5", "229.5", "90e8cf", "70b4a1", unicode"江戸川"];

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

        string[5][] memory unlockedStamps = retrieveUnlocks(tokenId);
        bytes memory encodedAttributes;
        for (uint256 i = 0; i < unlockedStamps.length; i++) {
            string[5] memory stamp = unlockedStamps[i];
            if (i == 0) {
                encodedAttributes = ",";
            }

            encodedAttributes = abi.encodePacked(encodedAttributes, '{"value":"', stamp[4], '"}');
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

    function buildSvg(string[5][] memory unlockedStamps) internal view returns (string memory) {
        string memory baseUrl = "data:image/svg+xml;base64,";

        bytes memory encodedStamps;
        for (uint256 i = 0; i < unlockedStamps.length; i++) {
            string[5] memory stamp = unlockedStamps[i];

            bytes memory stampSvg = abi.encodePacked(
                '<g transform="translate(',
                abi.encodePacked(stamp[0], ",", stamp[1]),
                ') scale(11)">',
                '<rect x="0.4375" y="0.4375" width="3.125" height="6.125" ry="1.70625" rx="2" fill="#ffffff" stroke="#',
                stamp[2],
                '" stroke-width="0.875" />',
                '<rect x="0.05" y="0.05" width="3.9" height="6.9" rx="2" ry="2" fill="none" stroke-width="0.15" stroke="#',
                stamp[2],
                '"/>',
                '<text x="1.75" y="3.5" font-family="Meiryo, sans-serif" alignment-baseline="middle" text-anchor="middle" fill="#',
                stamp[3],
                '" style="font-size: 8.25%; font-weight: 600; letter-spacing: 0.1; writing-mode: vertical-rl;">',
                stamp[4],
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

    function retrieveUnlocks(uint256 tokenId) public view returns (string[5][] memory) {
        uint256 unlocked = unlocks[tokenId];

        // determine size to be declared
        uint256 length = 0;
        for (uint256 i = 0; i < 23; i++) {
            if ((unlocked >> i) & 1 == 1) {
                length++;
            }
        }

        string[5][] memory output = new string[5][](length);

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

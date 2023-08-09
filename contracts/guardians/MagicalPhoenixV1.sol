// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "../citizenid/CitizenIDV2.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";

/// @title MagicalPhoenix NFT contract
/// @author Tevaera Labs
/// @notice Allows users to mint the guardian NFT of MagicalPhoenix
/// @dev It extends ERC721 and ERC2981 standards
contract MagicalPhoenixV1 is
    ERC721RoyaltyUpgradeable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    CitizenIDV2 private citizenIdContract;

    modifier isNotBlacklisted() {
        require(
            !citizenIdContract.blacklisted(msg.sender),
            "Tevan Blacklisted!"
        );
        _;
    }

    modifier isTevan() {
        require(citizenIdContract.balanceOf(msg.sender) > 0, "Not a Tevan");
        _;
    }

    mapping(address => bool) public whitelisted;
    uint256 public constant MAX_PHOENIXES = 5000;
    /// @dev Contract level metadata.
    string public contractURI;

    mapping(address => bool) private addressToHasMintedMap;
    mapping(uint256 => uint256) private availableTokens;
    uint256 private randomNonce = 0;
    uint256 private numAvailableTokens;
    string private tokenBaseUri;

    /// @dev Initializes the upgradable contract
    /// @param _citizenIdContract the citizen id contract address
    /// @param _tokenBaseUri the token base uri
    function initialize(
        CitizenIDV2 _citizenIdContract,
        string calldata _contractUri,
        string calldata _tokenBaseUri,
        address safeAddress
    ) external initializer {
        __ERC721_init("MagicalPhoenix", "PHOENIX");
        __ERC721Enumerable_init();
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __ERC721Royalty_init();

        citizenIdContract = _citizenIdContract;
        contractURI = _contractUri;
        tokenBaseUri = _tokenBaseUri;

        // set default royalty to 2.5%
        _setDefaultRoyalty(safeAddress, 250);

        // set random nonce starting index
        randomNonce = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(
                        abi.encode(
                            tx.gasprice,
                            block.number,
                            block.timestamp,
                            block.prevrandao,
                            blockhash(block.number - 1),
                            address(this)
                        )
                    )
                )
            )
        );

        numAvailableTokens = MAX_PHOENIXES;
    }

    /// @dev Mints Guardian NFT
    function mint()
        external
        payable
        isTevan
        isNotBlacklisted
        whenNotPaused
        nonReentrant
    {
        // make sure caller is whitelisted
        require(whitelisted[msg.sender] == true, "not whitelisted");

        // make sure caller has not already minted
        require(addressToHasMintedMap[msg.sender] == false, "already minted");

        // make sure phoenixes are not sold out
        require(totalSupply() + 1 <= MAX_PHOENIXES, "sold out");

        // get the random token id
        uint256 tokenId = getRandomAvailableTokenId(msg.sender, randomNonce);

        // mint the guardian nft
        _mint(msg.sender, tokenId);

        // mark address as minted
        addressToHasMintedMap[msg.sender] = true;

        // increase the nonce
        randomNonce++;

        // reduce the available token count
        --numAvailableTokens;
    }

    /// @dev Lets a contract admin set the URI for the contract-level metadata.
    function setContractURI(string calldata _uri) external onlyOwner {
        contractURI = _uri;
    }

    /// @dev Sets the royalty info
    /// @param _safeAddress the royalty receiver address
    /// @param _royaltyBps the royalty percentage in basis points
    function setRoyaltyInfo(
        address _safeAddress,
        uint8 _royaltyBps
    ) external onlyOwner whenNotPaused {
        _setDefaultRoyalty(_safeAddress, _royaltyBps);
    }

    /// @dev Sets the token base uri
    /// @param _tokenBaseUri the token base uri
    function setTokenBaseUri(
        string calldata _tokenBaseUri
    ) external onlyOwner whenNotPaused {
        tokenBaseUri = _tokenBaseUri;
    }

    /// @dev Allows owner to whitelist wallet addresses
    /// @param addresses the list of wallet addresses that need to be whitelisted
    function whitelistAddresses(
        address[] calldata addresses
    ) external onlyOwner whenNotPaused {
        uint256 len = addresses.length;
        for (uint256 i = 0; i < len; ) {
            require(addresses[i] != address(0), "Invalid address");

            if (!whitelisted[addresses[i]]) {
                whitelisted[addresses[i]] = true;
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Allows owner to remove wallet addresses from the whitelist
    /// @param addresses the list of wallet addresses that need to be removed from whitelist
    function removeWhitelistAddresses(
        address[] calldata addresses
    ) external onlyOwner whenNotPaused {
        uint256 len = addresses.length;
        for (uint256 i = 0; i < len; ) {
            require(addresses[i] != address(0), "Invalid address");

            if (!whitelisted[addresses[i]]) {
                whitelisted[addresses[i]] = false;
            }

            unchecked {
                ++i;
            }
        }
    }

    // ----- system default functions -----

    /// @dev Allows owner to pause sale if active
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @dev Allows owner to acticvate sale
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    function getRandomAvailableTokenId(
        address to,
        uint256 nonce
    ) internal returns (uint256) {
        uint256 randomNum = uint256(
            keccak256(
                abi.encodePacked(
                    keccak256(
                        abi.encode(
                            to,
                            nonce,
                            tx.gasprice,
                            block.number,
                            block.timestamp,
                            block.prevrandao,
                            blockhash(block.number - 1),
                            address(this)
                        )
                    )
                )
            )
        ) % numAvailableTokens;

        return getAvailableTokenAtIndex(randomNum);
    }

    function getAvailableTokenAtIndex(
        uint256 indexToUse
    ) internal returns (uint256) {
        uint256 valAtIndex = availableTokens[indexToUse];
        uint256 result;
        if (valAtIndex == 0) {
            // This means the index itself is still an available token
            result = indexToUse;
        } else {
            // This means the index itself is not an available token, but the val at that index is.
            result = valAtIndex;
        }

        uint256 lastIndex = numAvailableTokens - 1;
        uint256 lastValInArray = availableTokens[lastIndex];
        if (indexToUse != lastIndex) {
            // Replace the value at indexToUse, now that it's been used.
            // Replace it with the data from the last index in the array, since we are going to decrease the array size afterwards.
            if (lastValInArray == 0) {
                // This means the index itself is still an available token
                availableTokens[indexToUse] = lastIndex;
            } else {
                // This means the index itself is not an available token, but the val at that index is.
                availableTokens[indexToUse] = lastValInArray;
            }
        }
        if (lastValInArray != 0) {
            // Gas refund courtsey of @dievardump
            delete availableTokens[lastIndex];
        }

        return result;
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721RoyaltyUpgradeable) {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _baseURI()
        internal
        view
        override(ERC721Upgradeable)
        returns (string memory)
    {
        return tokenBaseUri;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721Upgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721EnumerableUpgradeable, ERC721RoyaltyUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

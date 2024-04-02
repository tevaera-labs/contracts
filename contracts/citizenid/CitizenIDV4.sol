// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/// @title A Citizen ID contract
/// @author Tevaera Labs
/// @notice Users need to mint the Citizen ID to become a Tevan
/// @dev It extends ERC721 standard
contract CitizenIDV4 is
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    //// @dev the claim contract address
    address public claimContract;
    //// @dev true, if the owner permits claiming of KPs for the time being
    bool public canClaim = false;
    /// @dev the token price in ETH
    uint256 public tokenPrice;

    CountersUpgradeable.Counter private tokenIdCounter;

    /// @dev the rep admin address
    address private repAdminAddress;

    /// @dev the safe address
    address payable private safeAddress;

    /// @dev the list of blacklisted wallet addresses
    mapping(address => bool) public blacklisted;

    /// @dev the list of token id -> rep score
    mapping(address => uint256) public tevanRep;

    /// @dev the token image uri
    string private tokenImageUri;

    /// @dev the token base uri
    string private tokenBaseUri;

    /// @dev check if the caller is the claim contract
    modifier onlyClaim() {
        require(msg.sender == claimContract, "not accessible");
        _;
    }

    /// @dev check if the caller is the rep admin
    modifier onlyRepAdmin() {
        require(msg.sender == repAdminAddress, "not accessible");
        _;
    }

    /// @dev Initializes the upgradable contract
    /// @param _tokenImageUri the token base uri
    /// @param _tokenPrice the token base price
    function initialize(
        string calldata _tokenImageUri,
        uint256 _tokenPrice
    ) external initializer {
        __ERC721_init("CitizenID", "TEVAN");
        __ERC721Enumerable_init();
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        tokenImageUri = _tokenImageUri;
        tokenPrice = _tokenPrice;

        // increament the counter
        tokenIdCounter.increment();
    }

    /// @dev Allows owner to blacklist any wallet address across Tevaera platform
    /// @param addresses the list of wallet addresses that need to be blocked
    function blacklistAddresses(
        address[] calldata addresses
    ) external onlyOwner {
        uint256 len = addresses.length;
        for (uint256 i = 0; i < len; ) {
            require(addresses[i] != address(0), "Invalid address");

            if (!blacklisted[addresses[i]]) {
                blacklisted[addresses[i]] = true;
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Allows owner to remove any wallet address from the blacklist
    /// @param addresses the list of wallet addresses that need to be unblocked
    function removeFromBlacklist(
        address[] calldata addresses
    ) external onlyOwner {
        uint256 len = addresses.length;

        for (uint256 i = 0; i < len; ) {
            if (blacklisted[addresses[i]]) {
                blacklisted[addresses[i]] = false;
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Mints the Citizen ID
    function mintToken(address tevan) internal nonReentrant {
        // make sure caller has not already minted the citizen id
        require(balanceOf(tevan) == 0, "Already a Tevan!");
        // make sure caller not blacklisted
        require(!blacklisted[tevan], "Tevan Blacklisted!");
        // price validation
        require(msg.value == tokenPrice, "Invalid amount");

        // mint
        mint(tevan);
    }

    /// @dev Mints the Citizen ID
    function mintCitizenId() external payable whenNotPaused {
        mintToken(msg.sender);
    }

    /// @dev Mints the Citizen ID
    function claim(address tevan) external payable onlyClaim whenNotPaused {
        require(canClaim == true, "Claim not enabled.");

        mintToken(tevan);
    }

    /// @dev Allows owner to pause sale if active
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @dev Allows owner to activate sale
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /// @dev An internal function to perform actual mint
    /// @param to a wallet address against which minting is being performed
    function mint(address to) internal {
        // update the counter
        uint256 tokenId = tokenIdCounter.current();
        tokenIdCounter.increment();
        // mint
        _mint(to, tokenId);
    }

    /// @dev Sets the token base uri
    /// @param _tokenBaseUri the token base uri
    function setTokenBaseUri(
        string calldata _tokenBaseUri
    ) external onlyOwner whenNotPaused {
        tokenBaseUri = _tokenBaseUri;
    }

    /// @dev Sets the token price
    /// @param _tokenPrice the token price in ETH
    function setTokenPrice(
        uint256 _tokenPrice
    ) external onlyOwner whenNotPaused {
        tokenPrice = _tokenPrice;
    }

    /// @dev Allows owner to update claim capability
    /// @param _claimContract the claim contract address
    /// @param _canClaim a flag to indicate whether to enable or disable the capability
    function updateClaimCapability(
        address _claimContract,
        bool _canClaim
    ) external onlyOwner {
        require(_claimContract != address(0), "Invalid address!");

        claimContract = _claimContract;
        canClaim = _canClaim;
    }

    /// @dev Allows owner to update the rep admin wallet address
    /// @param _repAdminAddress the rep admin wallet address
    function updateRepAdminAddress(
        address _repAdminAddress
    ) external onlyOwner {
        require(_repAdminAddress != address(0), "Invalid address!");
        repAdminAddress = _repAdminAddress;
    }

    /// @dev Allows owner to update the safe wallet address
    /// @param _safeAddress the safe wallet address
    function updateSafeAddress(
        address payable _safeAddress
    ) external onlyOwner {
        require(_safeAddress != address(0), "Invalid address!");
        safeAddress = _safeAddress;
    }

    /// @dev Withdraws funds from this contract to safe address
    function withdrawFunds() external onlyOwner {
        require(safeAddress != address(0), "Missing safe address!");
        (bool success, ) = payable(safeAddress).call{
            value: (address(this).balance)
        }("");
        require(success, "Transfer failed.");
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
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
        require(from == address(0), "Token not transferable");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
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
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        //////////////////////// V4 Changes ////////////////////////
        // Return the same metadata URI for all tokens since they are identical.
        // Due to the citizen ID count surpassing 500,000, managing millions of data entries on IPFS becomes challenging.

        // return super.tokenURI(tokenId);
        return tokenBaseUri;
    }

    //////////////////////// V3 Changes ////////////////////////
    // Add Contract Metadata

    /// @dev Contract level metadata.
    string public contractURI;

    /// @dev Lets a contract admin set the URI for the contract-level metadata.
    function setContractURI(string calldata _uri) external onlyOwner {
        contractURI = _uri;
    }

    // Add a function that enables addresses listed on the whitelist to mint tokens on behalf of other addresses.

    /// @dev the list of whitelisted callers
    mapping(address => bool) public whitelistedCallers;

    /// @dev Allows owner to blacklist any wallet address across Tevaera platform
    /// @param addresses the list of wallet addresses that need to be blocked
    function whitelistCallers(address[] calldata addresses) external onlyOwner {
        uint256 len = addresses.length;
        for (uint256 i = 0; i < len; ) {
            require(addresses[i] != address(0), "Invalid address");

            if (!whitelistedCallers[addresses[i]]) {
                whitelistedCallers[addresses[i]] = true;
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Mint token for a specified address when called by whitelisted callers
    function mintForAddress(address recipient) external payable whenNotPaused {
        require(whitelistedCallers[msg.sender], "Caller is not whitelisted");

        mintToken(recipient);
    }
}

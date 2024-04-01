// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "../../external/layer-zero/ONFT721CoreUpgradeable.sol";

/// @title InnovativeUnicorn NFT contract
/// @author Tevaera Labs
/// @notice Allows users to mint the guardian ONFT of InnovativeUnicorn
/// @dev It extends ERC721 and ERC2981 standards
contract InnovativeUnicornV1 is
    ERC721RoyaltyUpgradeable,
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ONFT721CoreUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /// @dev the safe address
    address payable private safeAddress;

    CountersUpgradeable.Counter private tokenIdCounter;

    /// @dev the token base uri
    string private tokenBaseUri;

    /// @dev Contract level metadata.
    string public contractURI;

    function initialize(
        address _lzEndpoint,
        address _safeAddress,
        uint256 _crosschainTransferFee,
        uint256 _minGasToTransferAndStore,
        string calldata _contractUri,
        string calldata _tokenBaseUri
    ) external initializer {
        __ERC721_init("Innovative Unicorn", "UNICORN");
        __ERC721Enumerable_init();
        __ERC721Royalty_init();
        __Ownable_init_unchained();
        __ONFT721CoreUpgradeable_init(
            _minGasToTransferAndStore,
            _lzEndpoint,
            _crosschainTransferFee,
            _safeAddress
        );
        __Pausable_init();
        __ReentrancyGuard_init();

        // set contract uri which contains contract level metadata
        contractURI = _contractUri;
        // set safe address
        safeAddress = payable(_safeAddress);
        // set token base uri
        tokenBaseUri = _tokenBaseUri;

        // set default royalty to 2.5%
        _setDefaultRoyalty(_safeAddress, 250);
    }

    /// @dev Lets a contract admin set the URI for the contract-level metadata.
    function setContractURI(string calldata _uri) external onlyOwner {
        contractURI = _uri;
    }

    /// @dev Sets the token base uri
    /// @param _tokenBaseUri the token base uri
    function setTokenBaseUri(
        string calldata _tokenBaseUri
    ) external onlyOwner whenNotPaused {
        tokenBaseUri = _tokenBaseUri;
    }

    /// @dev Allows owner to update the safe wallet address
    /// @param _safeAddress the safe wallet address
    function updateSafeAddress(
        address payable _safeAddress
    ) external onlyOwner {
        require(_safeAddress != address(0), "Invalid address!");
        safeAddress = _safeAddress;
    }

    /// @dev Withdraws the funds
    function withdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            // Withdraw Ether
            require(
                address(this).balance >= amount,
                "Insufficient Ether balance"
            );
            // Transfer Ether to the owner
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Ether transfer failed");
        } else {
            // Withdraw ERC-20 tokens
            IERC20Upgradeable erc20Token = IERC20Upgradeable(token);
            uint256 contractBalance = erc20Token.balanceOf(address(this));
            require(contractBalance >= amount, "Insufficient token balance");
            // Transfer ERC-20 tokens to the owner
            require(
                erc20Token.transfer(msg.sender, amount),
                "Token transfer failed"
            );
        }
    }

    /// @dev Debits a token from user's account to transfer it to another chain
    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint _tokenId
    ) internal virtual override {
        require(
            _from == _msgSender(),
            "ProxyONFT721: owner is not send caller"
        );

        _burn(_tokenId);
    }

    /// @dev Credits a token to user's account received from another chain
    function _creditTo(
        uint16,
        address _toAddress,
        uint _tokenId
    ) internal virtual override {
        _safeMint(_toAddress, _tokenId);
    }

    // ----- system default functions -----

    /// @dev Allows owner to pause sale if active
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @dev Allows owner to activate sale
    function unpause() public onlyOwner whenPaused {
        _unpause();
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

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721RoyaltyUpgradeable,
            ERC721EnumerableUpgradeable,
            ONFT721CoreUpgradeable
        )
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
    ) public view override(ERC721Upgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}

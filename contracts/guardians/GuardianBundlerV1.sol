// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./BalancerDragonV1.sol";
import "./InfluentialWerewolfV1.sol";
import "./InnovativeUnicornV1.sol";
import "./NomadicYetiV1.sol";
import "./SimplifierKrakenV1.sol";

/// @title Airdrop claim contract for Citizen ID & Karma Points
/// @author Tevaera Labs
/// @notice Claims airdropped Citizen ID & Karma Points
/// @dev Uses CitizenID and KarmaPoint contracts for minting
contract GuardianBundlerV1 is OwnableUpgradeable, PausableUpgradeable {
    /// @dev the safe address
    address payable private safeAddress;

    /// @dev the instances of guardian contracts
    BalancerDragonV1 internal balancerDragon;
    InfluentialWerewolfV1 internal influentialWerewolf;
    InnovativeUnicornV1 internal innovativeUnicorn;
    NomadicYetiV1 internal nomadicYeti;
    SimplifierKrakenV1 internal simplifierKraken;

    /// @dev the bundle price in ETH
    uint256 public bundlePrice;

    constructor(
        BalancerDragonV1 _balancerDragon,
        InfluentialWerewolfV1 _influentialWerewolf,
        InnovativeUnicornV1 _innovativeUnicorn,
        NomadicYetiV1 _nomadicYeti,
        SimplifierKrakenV1 _simplifierKraken,
        address _safeAddress,
        uint256 _bundlePrice
    ) {
        balancerDragon = _balancerDragon;
        influentialWerewolf = _influentialWerewolf;
        innovativeUnicorn = _innovativeUnicorn;
        nomadicYeti = _nomadicYeti;
        simplifierKraken = _simplifierKraken;
        safeAddress = payable(_safeAddress);
        bundlePrice = _bundlePrice;
    }

    /// @notice Users gets citizen id and karma points if eligible
    /// @dev Mints citizen id and karma poins
    function mintBundle() external payable whenNotPaused {
        // price validation
        require(msg.value == bundlePrice, "Invalid amount");

        // mint all guardians
        balancerDragon.mintForBundler();
        influentialWerewolf.mintForBundler();
        innovativeUnicorn.mintForBundler();
        nomadicYeti.mintForBundler();
        simplifierKraken.mintForBundler();
    }

    /// @dev Owner can update the citizen id contract address
    function setBalancerDragon(
        BalancerDragonV1 _balancerDragon
    ) external onlyOwner {
        balancerDragon = _balancerDragon;
    }

    /// @dev Owner can update the citizen id contract address
    function setInfluentialWerewolf(
        InfluentialWerewolfV1 _influentialWerewolf
    ) external onlyOwner {
        influentialWerewolf = _influentialWerewolf;
    }

    /// @dev Owner can update the citizen id contract address
    function setInnovativeUnicorn(
        InnovativeUnicornV1 _innovativeUnicorn
    ) external onlyOwner {
        innovativeUnicorn = _innovativeUnicorn;
    }

    /// @dev Owner can update the citizen id contract address
    function setNomadicYeti(NomadicYetiV1 _nomadicYeti) external onlyOwner {
        nomadicYeti = _nomadicYeti;
    }

    /// @dev Owner can update the citizen id contract address
    function setSimplifierKraken(
        SimplifierKrakenV1 _simplifierKraken
    ) external onlyOwner {
        simplifierKraken = _simplifierKraken;
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
            require(amount > 0, "Amount must be greater than zero");
            require(
                address(this).balance >= amount,
                "Insufficient Ether balance"
            );

            // Transfer Ether to the owner
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Ether transfer failed");
        } else {
            // Withdraw ERC-20 tokens
            require(amount > 0, "Amount must be greater than zero");

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

    /// @dev Owner can pasue the claim
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    /// @dev Owner can activate the claim
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }
}

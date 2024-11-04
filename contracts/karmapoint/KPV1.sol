// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

// Importing necessary OpenZeppelin contracts for access control, reentrancy guard, and ERC20 functionality
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @title Karma Point Contract
/// @author Tevaera Labs
/// @notice A contract for managing Karma Points, allowing minting, burning, and withdrawals.
/// @dev This contract is upgradeable and uses OpenZeppelin standards for security and functionality.
contract KarmaPointV1 is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable; // Using SafeERC20 for safe token operations

    // Role definitions
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant DEX_ROLE = keccak256("DEX_ROLE");

    // Event to log withdrawals
    event Withdraw(address indexed token, address indexed to, uint256 amount);

    /// @dev Initializes the upgradable contract
    function initialize() external initializer {
        __ERC20_init("KarmaPoint", "KP");
        __ERC20Pausable_init();
        __ReentrancyGuard_init();
        __AccessControl_init();

        // Grant roles to the contract deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    // -------------------------- Minting Functions ---------------------------

    /// @dev Mint new Karma Points to a specified address
    /// @param to The address receiving the newly minted Karma Points
    /// @param amount The amount of Karma Points to mint
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount); // Call the internal mint function
    }

    // -------------------------- DEX Approval Functions ----------------------

    /// @dev Approve a DEX to handle KP transfers
    /// @param dexAddress The address of the DEX to approve
    function approveDEX(
        address dexAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(DEX_ROLE, dexAddress);
    }

    /// @dev Revoke DEX approval
    /// @param dexAddress The address of the DEX to revoke
    function revokeDEX(
        address dexAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(DEX_ROLE, dexAddress);
    }

    /// @dev Check if an address is an approved DEX
    /// @param dexAddress The address of the DEX to check
    /// @return True if the address is an approved DEX, otherwise false
    function isApprovedDEX(address dexAddress) external view returns (bool) {
        return hasRole(DEX_ROLE, dexAddress);
    }

    // -------------------------- Pausing Functions ---------------------------

    /// @dev Pause the contract to prevent transfers and minting
    function pause() public onlyRole(PAUSER_ROLE) whenNotPaused {
        _pause();
    }

    /// @dev Unpause the contract to allow transfers and minting
    function unpause() public onlyRole(PAUSER_ROLE) whenPaused {
        _unpause();
    }

    // -------------------------- Burning Function ----------------------------

    /// @dev Burn Karma Points from a specified address
    /// @param from The address from which Karma Points are to be burned
    /// @param amount The amount of Karma Points to burn
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount); // Call the internal burn function
    }

    // -------------------------- Withdrawal Function -------------------------

    /// @dev Withdraw Ether or ERC-20 tokens from the contract
    /// @param safeAddress The address to which funds should be sent
    /// @param token The address of the token to withdraw (use address(0) for Ether)
    /// @param amount The amount of tokens or Ether to withdraw
    function withdraw(
        address safeAddress,
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(safeAddress != address(0), "Invalid safe address");
        require(amount > 0, "Invalid amount");

        if (token == address(0)) {
            // Withdraw Ether
            require(
                address(this).balance >= amount,
                "Insufficient Ether balance"
            );

            // Transfer Ether to the specified safe address
            (bool success, ) = payable(safeAddress).call{value: amount}("");
            require(success, "Ether transfer failed");
        } else {
            // Withdraw ERC-20 tokens
            IERC20Upgradeable erc20Token = IERC20Upgradeable(token);
            uint256 contractBalance = erc20Token.balanceOf(address(this));
            require(contractBalance >= amount, "Insufficient token balance");

            // Transfer ERC-20 tokens to the specified safe address safely
            erc20Token.safeTransfer(safeAddress, amount);
        }

        // Emit a withdrawal event
        emit Withdraw(token, safeAddress, amount);
    }

    // -------------------------- Utility Functions ---------------------------

    /// @dev Override the decimals value for Karma Point tokens to 0
    /// @return uint8 The number of decimals
    function decimals() public view virtual override returns (uint8) {
        return 0; // No decimals for Karma Points
    }

    // -------------------------- Overrides ----------------------------------

    /// @dev Override the _beforeTokenTransfer function
    /// @param from The address transferring the tokens
    /// @param to The address receiving the tokens
    /// @param amount The amount being transferred
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._beforeTokenTransfer(from, to, amount); // Call the base class implementations

        // Prevent token transfers while paused
        require(!paused(), "Token transfer while paused");
    }

    /// @dev Override the transfer function to restrict transfers to approved DEXs
    /// @param recipient The address to receive the tokens
    /// @param amount The amount to transfer
    /// @return bool True if the transfer was successful
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            hasRole(DEX_ROLE, msg.sender),
            "Transfers only allowed through approved DEXs"
        );
        return super.transfer(recipient, amount);
    }

    /// @dev Override the transferFrom function to restrict transfers to approved DEXs
    /// @param sender The address transferring the tokens
    /// @param recipient The address to receive the tokens
    /// @param amount The amount to transfer
    /// @return bool True if the transfer was successful
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            hasRole(DEX_ROLE, msg.sender),
            "Transfers only allowed through approved DEXs"
        );
        return super.transferFrom(sender, recipient, amount);
    }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

// oz imports
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// zksync imports for paymaster
import {IPaymaster, ExecutionResult, PAYMASTER_VALIDATION_SUCCESS_MAGIC} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymaster.sol";
import {IPaymasterFlow} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymasterFlow.sol";
import {TransactionHelper, Transaction} from "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";

contract TevaPaymasterV1 is IPaymaster, OwnableUpgradeable {
    /// @dev the safe address
    address payable private safeAddress;
    /// @dev admin address
    address private adminAddress;
    /// @dev teva market contract address
    address public tevaMarket;
    /// @dev price buffer bps
    uint16 private priceBufferBps;
    /// @dev token address => tokenDecimal
    mapping(address => uint8) public tokenDecimals; // Token Decimals i.e. 18 for USDC, 8 for wBTC, etc.
    /// @dev token address => price in cents ($1 = 100)
    mapping(address => uint64) public tokenPricesInUSD; // Price in Cents i.e. $1 = 100
    /// @dev contract => isWhitelisted
    mapping(address => bool) public whitelistedContracts;
    /// @dev mapping to track whether a wallet address is eligible for gasless transactions
    mapping(address => bool) public eligibleGaslessWallets;

    address public constant NATIVE_TOKEN =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public constant MIN_TX_AMOUNT = 100000000000000000; // txn with more than 0.1 ETH;

    modifier onlyBootloader() {
        require(
            msg.sender == BOOTLOADER_FORMAL_ADDRESS,
            "Only bootloader can call this method"
        );
        // Continue execution if called from the bootloader.
        _;
    }

    /// @dev check if the caller is an admin
    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "not accessible");
        _;
    }

    function initialize(
        address _adminAddress,
        address _tevaMarket,
        uint16 _priceBufferBps,
        address[] calldata _allowedTokens,
        uint64[] calldata _prices,
        uint8[] calldata _tokenDecimals
    ) external initializer {
        require(
            _allowedTokens.length == _prices.length &&
                _allowedTokens.length == _tokenDecimals.length,
            "Different arrays lengths"
        );

        // init
        __Ownable_init();

        // set admin address
        adminAddress = _adminAddress;
        // set teva market address
        tevaMarket = _tevaMarket;
        // set price buffer bps
        priceBufferBps = _priceBufferBps;

        // set allowed erc20 tokens
        for (uint256 i = 0; i < _allowedTokens.length; ) {
            require(_allowedTokens[i] != address(0), "Zero Address");
            require(_prices[i] > 0, "Zero Price");

            tokenPricesInUSD[_allowedTokens[i]] = _prices[i];
            tokenDecimals[_allowedTokens[i]] = _tokenDecimals[i];

            unchecked {
                ++i;
            }
        }
    }

    function updateAdminAddress(address _adminAddress) external onlyOwner {
        require(_adminAddress != address(0), "Zero Address");

        adminAddress = _adminAddress;
    }

    function updatePriceBufferBps(uint16 _priceBufferBps) external onlyOwner {
        require(_priceBufferBps > 0, "Zero Value");

        priceBufferBps = _priceBufferBps;
    }

    /// @dev Allows owner to update the safe wallet address
    /// @param _safeAddress the safe wallet address
    function updateSafeAddress(
        address payable _safeAddress
    ) external onlyOwner {
        require(_safeAddress != address(0), "Invalid address!");
        safeAddress = _safeAddress;
    }

    function updateTokenDecimals(
        address[] calldata _tokenAddresses,
        uint8[] calldata _decimals
    ) external onlyOwner {
        require(
            _tokenAddresses.length == _decimals.length,
            "Different arrays lengths"
        );

        for (uint256 i = 0; i < _tokenAddresses.length; ) {
            require(_tokenAddresses[i] != address(0), "Zero Address");

            tokenDecimals[_tokenAddresses[i]] = _decimals[i];

            unchecked {
                ++i;
            }
        }
    }

    function updateTokenPrices(
        address[] calldata _tokenAddresses,
        uint64[] calldata _prices
    ) external onlyAdmin {
        require(
            _tokenAddresses.length == _prices.length,
            "Different arrays lengths"
        );

        for (uint256 i = 0; i < _tokenAddresses.length; ) {
            require(_tokenAddresses[i] != address(0), "Zero Address");

            if (_prices[i] == 0) {
                delete tokenPricesInUSD[_tokenAddresses[i]];
            } else {
                tokenPricesInUSD[_tokenAddresses[i]] = _prices[i];
            }

            unchecked {
                ++i;
            }
        }
    }

    function updateEligibleWallets(
        address[] calldata _wallets,
        bool isEligible
    ) external onlyOwner {
        // set wallets that are eligible for gasless transactions
        for (uint256 i = 0; i < _wallets.length; ) {
            require(_wallets[i] != address(0), "Zero Address");

            eligibleGaslessWallets[_wallets[i]] = isEligible;

            unchecked {
                ++i;
            }
        }
    }

    function updateWhitelistedContracts(
        address[] calldata _contracts,
        bool[] calldata _isWhitelisted
    ) external onlyOwner {
        require(
            _contracts.length == _isWhitelisted.length,
            "Different arrays lengths"
        );

        for (uint256 i = 0; i < _contracts.length; ) {
            require(_contracts[i] != address(0), "Zero Address");

            whitelistedContracts[_contracts[i]] = _isWhitelisted[i];

            unchecked {
                ++i;
            }
        }
    }

    function validateAndPayForPaymasterTransaction(
        bytes32,
        bytes32,
        Transaction calldata _transaction
    )
        external
        payable
        onlyBootloader
        returns (bytes4 magic, bytes memory context)
    {
        // By default we consider the transaction as accepted.
        magic = PAYMASTER_VALIDATION_SUCCESS_MAGIC;
        require(
            _transaction.paymasterInput.length >= 4,
            "The standard paymaster input must be at least 4 bytes long"
        );

        bytes4 paymasterInputSelector = bytes4(
            _transaction.paymasterInput[0:4]
        );

        // handle approval based flow - mainly for erc20 tokens
        if (paymasterInputSelector == IPaymasterFlow.approvalBased.selector) {
            handleApprovalBasedFlow(_transaction);
        } else if (paymasterInputSelector == IPaymasterFlow.general.selector) {
            handleGeneralFlow(_transaction);
        } else {
            revert("Unsupported paymaster flow");
        }
    }

    function handleApprovalBasedFlow(
        Transaction calldata _transaction
    ) internal {
        // contract address
        address caller = address(uint160(_transaction.to));
        // Verfiy if caller is whitelisted
        require(whitelistedContracts[caller] == true, "Unauthorized");

        // While the transaction data consists of address, uint256 and bytes data,
        // the data is not needed for this paymaster
        (address token, uint256 amount, ) = abi.decode(
            _transaction.paymasterInput[4:],
            (address, uint256, bytes)
        );
        // Verify if token is allowed & have correct price
        require(tokenPricesInUSD[token] > 0, "Invalid token");

        // calculate required gas in eth
        uint256 requiredEth = _transaction.gasLimit * _transaction.maxFeePerGas;
        // user address
        address userAddress = address(uint160(_transaction.from));
        // We verify that the user has provided enough allowance
        address thisAddress = address(this);

        uint256 providedAllowance = IERC20Upgradeable(token).allowance(
            userAddress,
            thisAddress
        );

        // Get token decimals
        uint8 additionalDecimals = 18 - tokenDecimals[token]; // additional decimal needed to make it 18
        // Get eth & token prices in USD
        uint64 ethUsdPrice = tokenPricesInUSD[NATIVE_TOKEN];
        uint64 tokenUsdPrice = tokenPricesInUSD[token];

        // Calculate the required ERC20 tokens to be sent to the paymaster
        // (Equal to the value of requiredEth)
        uint256 requiredToken = (requiredEth * ethUsdPrice) /
            (tokenUsdPrice * (10 ** additionalDecimals));
        uint256 bufferAmount = (requiredToken * priceBufferBps) / 10 ** 4;

        // Add buffer to the required amount
        requiredToken = requiredToken + bufferAmount;

        require(
            providedAllowance >= requiredToken,
            "Min paying allowance too low"
        );

        // Note, that while the minimal amount of ETH needed is tx.gasPrice * tx.gasLimit,
        // neither paymaster nor account are allowed to access this context variable.
        try
            IERC20Upgradeable(token).transferFrom(
                userAddress,
                thisAddress,
                requiredToken
            )
        {} catch (bytes memory revertReason) {
            // If the revert reason is empty or represented by just a function selector,
            // we replace the error with a more user-friendly message
            if (requiredToken > amount) {
                revert("Not the required amount of tokens sent");
            }
            if (revertReason.length <= 4) {
                revert("Failed to transferFrom from users' account");
            } else {
                assembly {
                    revert(add(0x20, revertReason), mload(revertReason))
                }
            }
        }

        // The bootloader never returns any data, so it can safely be ignored here.
        (bool success, ) = payable(BOOTLOADER_FORMAL_ADDRESS).call{
            value: requiredEth
        }("");
        require(success, "Failed to transfer funds to the bootloader");
    }

    function handleGeneralFlow(Transaction calldata _transaction) internal {
        // contract address
        address caller = address(uint160(_transaction.to));
        // verfiy if caller is whitelisted
        require(whitelistedContracts[caller] == true, "Unauthorized");

        // user address
        address userAddress = address(uint160(_transaction.from));
        // check if the user is whitelisted for gasless transactions.
        // if not, then verify if they are eligible for the buy promotion.
        if (eligibleGaslessWallets[userAddress] == false) {
            // extracting the function selector from the transaction
            bytes4 funcSlct = bytes4(_transaction.data);
            // marketplace's buy function
            bytes4 buyFuncSlct = bytes4(
                keccak256("buy(uint256[],uint256[],address,address,uint256)")
            );
            // amount being passed
            uint256 txAmount = _transaction.value;
            // if the user is trying to buy an asset worth more than 0.1 ETH, we will bear the gas fees.
            bool isGaslessBuy = caller == tevaMarket &&
                funcSlct == buyFuncSlct &&
                txAmount > MIN_TX_AMOUNT;

            // Verify is the user is eligible for a gasless flow
            if (!isGaslessBuy) {
                revert("Not eligible for gasless transaction");
            }
        }

        // Calculate required gas in eth
        uint256 requiredEth = _transaction.gasLimit * _transaction.maxFeePerGas;
        // The bootloader never returns any data, so it can safely be ignored here.
        (bool success, ) = payable(BOOTLOADER_FORMAL_ADDRESS).call{
            value: requiredEth
        }("");
        require(success, "Failed to transfer funds to the bootloader");
    }

    function postTransaction(
        bytes calldata _context,
        Transaction calldata _transaction,
        bytes32,
        bytes32,
        ExecutionResult _txResult,
        uint256 _maxRefundedGas
    ) external payable override onlyBootloader {}

    // Function to withdraw Ether or ERC-20 tokens from the contract
    function withdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            // Withdraw Ether
            require(
                address(this).balance >= amount,
                "Insufficient Ether balance"
            );

            // Transfer Ether to the owner
            (bool success, ) = payable(safeAddress).call{value: amount}("");
            require(success, "Ether transfer failed");
        } else {
            // Withdraw ERC-20 tokens
            IERC20Upgradeable erc20Token = IERC20Upgradeable(token);
            uint256 contractBalance = erc20Token.balanceOf(address(this));
            require(contractBalance >= amount, "Insufficient token balance");

            // Transfer ERC-20 tokens to the owner
            require(
                erc20Token.transfer(safeAddress, amount),
                "Token transfer failed"
            );
        }
    }

    receive() external payable {}
}

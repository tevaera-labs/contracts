// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IFactory {
  /// @notice Event emitted when a contract is created with the factory
  /// @param creator The message sender
  /// @param created The created contract
  event ContractCreated(address indexed creator, address created);

  /// @notice Creates a new contract
  /// @param constructorData The constructor data passed to the new contract
  /// @return created The created contract address
  function create(
    bytes memory constructorData
  ) external returns (address created);
}
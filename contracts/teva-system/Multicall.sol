// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

/**
 * @title Multicall
 * @dev Contract that aggregates multiple contract function calls into a single call.
 */
contract Multicall {
    // Event emitted when calls are aggregated
    event AggregatedCalls(uint256 count);

    /**
     * @notice Aggregate non-payable multiple calls into a single call.
     * @param targets The addresses of the contracts to call.
     * @param callDatas The function call data for the corresponding contracts.
     * @return returnDatas The return data for each call.
     */
    function aggregate(
        address[] calldata targets,
        bytes[] calldata callDatas
    ) external returns (bytes[] memory returnDatas) {
        // Ensure the input arrays match in length.
        require(targets.length == callDatas.length, "Mismatched input arrays");

        // Initialize the return data array.
        returnDatas = new bytes[](targets.length);

        // Loop through each target address and call data, executing the calls.
        for (uint i = 0; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].call(callDatas[i]);

            // If any of the calls fails, revert the entire transaction.
            if (!success) {
                // Decode the standard Error(string) response for better error handling
                string memory errorMessage;
                if (result.length > 0) {
                    errorMessage = abi.decode(result, (string));
                } else {
                    errorMessage = "Call failed without a revert message";
                }
                revert(errorMessage);
            }

            returnDatas[i] = result;
        }

        emit AggregatedCalls(targets.length);
    }

    /**
     * @notice Aggregate payable multiple calls into a single call.
     * @param targets The addresses of the contracts to call.
     * @param callDatas The function call data for the corresponding contracts.
     * @param callDatas The values for the corresponding call datas.
     * @return returnDatas The return data for each call.
     */
    function aggregatePayable(
        address[] calldata targets,
        bytes[] calldata callDatas,
        uint256[] calldata values
    ) external payable returns (bytes[] memory returnDatas) {
        require(
            targets.length == callDatas.length &&
                targets.length == values.length,
            "Mismatched input arrays"
        );

        returnDatas = new bytes[](targets.length);

        for (uint i = 0; i < targets.length; i++) {
            (bool success, bytes memory result) = targets[i].call{
                value: values[i]
            }(callDatas[i]);

            // If any of the calls fails, revert the entire transaction.
            if (!success) {
                // Decode the standard Error(string) response for better error handling
                string memory errorMessage;
                if (result.length > 0) {
                    errorMessage = abi.decode(result, (string));
                } else {
                    errorMessage = "Call failed without a revert message";
                }
                revert(errorMessage);
            }

            returnDatas[i] = result;
        }

        // Ensure no leftover Ether remains in this contract.
        uint256 remainingValue = address(this).balance;
        if (remainingValue > 0) {
            payable(msg.sender).transfer(remainingValue);
        }

        emit AggregatedCalls(targets.length);
    }
}

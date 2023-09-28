// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Session is Ownable {
    struct SessionInfo {
        uint256 version;
        uint256 expirationTime;
        bool expired;
        mapping(address => bool) trustedAddressList;
    }

    mapping(address => SessionInfo) public sessions;

    function createSession(
        address authorizedSigner,
        uint256 secondsUntilEndTime,
        address[] calldata trustedAddresses
    ) external onlyOwner {
        sessions[authorizedSigner].version += 1;
        sessions[authorizedSigner].expirationTime =
            block.timestamp +
            secondsUntilEndTime;
        sessions[authorizedSigner].expired = false;

        uint256 len = trustedAddresses.length;
        for (uint256 i = 0; i < len; ) {
            require(trustedAddresses[i] != address(0), "Invalid address");

            sessions[authorizedSigner].trustedAddressList[
                trustedAddresses[i]
            ] = true;

            unchecked {
                ++i;
            }
        }
    }

    function deleteSession(address authorizedSigner) external onlyOwner {
        sessions[authorizedSigner].expirationTime = block.timestamp;
        sessions[authorizedSigner].expired = true;
    }

    function inSession(
        address authorizedSigner,
        address to
    ) internal view returns (bool) {
        if (sessions[authorizedSigner].expired) {
            return false;
        }

        return true;
    }
}

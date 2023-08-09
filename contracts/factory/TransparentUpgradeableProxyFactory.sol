// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {TransparentUpgradeableProxy} from "../proxy/transparent/TransparentUpgradeableProxy.sol";
import {IFactory} from "./interfaces/IFactory.sol";

contract TransparentUpgradeableProxyFactory is IFactory {
    /// @inheritdoc IFactory
    function create(
        bytes memory constructorData
    ) external override returns (address created) {
        (address _logic, address admin_, bytes memory _data) = abi.decode(
            constructorData,
            (address, address, bytes)
        );

        created = address(new TransparentUpgradeableProxy(_logic, admin_, _data));

        emit ContractCreated(msg.sender, created);
    }
}

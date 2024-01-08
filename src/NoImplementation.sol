// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NoImplementation is UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal virtual override {
        // anybody can steal this proxy
    }
}

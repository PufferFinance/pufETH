// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";

/**
 * @title Base Script
 * @author Puffer Finance
 */
abstract contract BaseScript is Script {
    uint256 internal PK = 55358659325830545179143827536745912452716312441367500916455484419538098489698; // makeAddr("pufferDeployer")

    /**
     * @dev Deployer private key is in `PK` env variable
     */
    uint256 internal _deployerPrivateKey = vm.envOr("PK", PK);
    address internal _broadcaster = vm.addr(_deployerPrivateKey);

    constructor() {
        // For local chain (ANVIL) hardcode the deployer as the first account from the blockchain
        if (isAnvil()) {
            // Fist account from ANVIL
            _deployerPrivateKey = uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
            _broadcaster = vm.addr(_deployerPrivateKey);
        }
    }

    modifier broadcast() {
        vm.startBroadcast(_deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }

    function isMainnet() internal view returns (bool) {
        return (block.chainid == 1);
    }

    function isHolesky() internal view returns (bool) {
        return (block.chainid == 17000);
    }

    function isAnvil() internal view returns (bool) {
        return (block.chainid == 31337);
    }
}

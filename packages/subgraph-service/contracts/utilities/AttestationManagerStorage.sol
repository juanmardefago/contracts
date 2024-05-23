// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

abstract contract AttestationManagerV1Storage {
    bytes32 internal _domainSeparator;

    /// @dev Gap to allow adding variables in future upgrades
    uint256[50] private __gap;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import { IDataService } from "./interfaces/IDataService.sol";

import { DataServiceV1Storage } from "./DataServiceStorage.sol";
import { GraphDirectory } from "../utilities/GraphDirectory.sol";
import { ProvisionManager } from "./utilities/ProvisionManager.sol";

/**
 * @title DataService contract
 * @dev Implementation of the {IDataService} interface.
 * @notice This implementation provides base functionality for a data service:
 * - GraphDirectory, allows the data service to interact with Graph Horizon contracts
 * - ProvisionManager, provides functionality to manage provisions
 *
 * The derived contract MUST implement all the interfaces described in {IDataService} and in
 * accordance with the Data Service framework.
 * @dev Implementation must initialize the contract using {__DataService_init} or
 * {__DataService_init_unchained} functions.
 */
abstract contract DataService is GraphDirectory, ProvisionManager, DataServiceV1Storage, IDataService {
    /**
     * @dev Addresses in GraphDirectory are immutables, they can only be set in this constructor.
     * @param controller The address of the Graph Horizon controller contract.
     */
    constructor(address controller) GraphDirectory(controller) {}

    /**
     * @notice Initializes the contract and any parent contracts.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __DataService_init() internal onlyInitializing {
        __DataService_init_unchained();
    }

    /**
     * @notice Initializes the contract.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __DataService_init_unchained() internal onlyInitializing {
        __ProvisionManager_init_unchained();
    }
}

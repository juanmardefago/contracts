// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { HorizonStakingTest } from "../HorizonStaking.t.sol";

contract HorizonStakingGovernanceTest is HorizonStakingTest {

    /*
     * MODIFIERS
     */

    modifier useGovernor {
        vm.startPrank(users.governor);
        _;
    }

    /*
     * TESTS
     */

    function testGovernance_SetAllowedLockedVerifier() public useGovernor {
        staking.setAllowedLockedVerifier(subgraphDataServiceAddress, true);
        assertTrue(staking.isAllowedLockedVerifier(subgraphDataServiceAddress));
    }

    function testGovernance_RevertWhen_SetAllowedLockedVerifier_NotGovernor() public useIndexer {
        bytes memory expectedError = abi.encodeWithSignature("ManagedOnlyGovernor()");
        vm.expectRevert(expectedError);
        staking.setAllowedLockedVerifier(subgraphDataServiceAddress, true);
    }

    function testGovernance_SetDelgationSlashing(bool enabled) public useGovernor {
        staking.setDelegationSlashingEnabled(enabled);
        assertEq(staking.isDelegationSlashingEnabled(), enabled);
    }

    function testGovernance_SetDelgationSlashing_NotGovernor(bool enabled) public useIndexer {
        bytes memory expectedError = abi.encodeWithSignature("ManagedOnlyGovernor()");
        vm.expectRevert(expectedError);
        staking.setDelegationSlashingEnabled(enabled);
    }

    function testGovernance_ClearThawingPeriod(uint32 thawingPeriod) public useGovernor {
        vm.store(address(staking), bytes32(uint256(13)), bytes32(uint256(thawingPeriod)));
        assertEq(staking.__DEPRECATED_getThawingPeriod(), thawingPeriod);
        
        staking.clearThawingPeriod();
        assertEq(staking.__DEPRECATED_getThawingPeriod(), 0);
    }

    function testGovernance_ClearThawingPeriod_NotGovernor() public useIndexer {
        bytes memory expectedError = abi.encodeWithSignature("ManagedOnlyGovernor()");
        vm.expectRevert(expectedError);
        staking.clearThawingPeriod();
    }

    function testGovernance__SetMaxThawingPeriod(uint64 maxThawingPeriod) public useGovernor {
        staking.setMaxThawingPeriod(maxThawingPeriod);
        assertEq(staking.getMaxThawingPeriod(), maxThawingPeriod);
    }

    function testGovernance__SetMaxThawingPeriod_NotGovernor() public useIndexer {
        bytes memory expectedError = abi.encodeWithSignature("ManagedOnlyGovernor()");
        vm.expectRevert(expectedError);
        staking.setMaxThawingPeriod(MAX_THAWING_PERIOD);
    }

    function testGovernance_SetCounterpartStakingAddress(address counterpartStakingAddress) public useGovernor {
        staking.setCounterpartStakingAddress(counterpartStakingAddress);
        bytes32 storedValue = vm.load(address(staking), bytes32(uint256(24)));
        address storedCounterpartStakingAddress = address(uint160(uint256(storedValue)));
        assertEq(storedCounterpartStakingAddress, counterpartStakingAddress);
    }

    function testGovernance_RevertWhen_SetCounterpartStakingAddress_NotGovernor(
        address counterpartStakingAddress
    ) public useIndexer {
        bytes memory expectedError = abi.encodeWithSignature("ManagedOnlyGovernor()");
        vm.expectRevert(expectedError);
        staking.setCounterpartStakingAddress(counterpartStakingAddress);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import { HorizonStakingExtensionTest } from "./HorizonStakingExtension.t.sol";
import { IHorizonStakingExtension } from "../../../contracts/interfaces/internal/IHorizonStakingExtension.sol";

contract HorizonStakingAllocationTest is HorizonStakingExtensionTest {

    /*
     * TESTS
     */

    function testAllocation_GetAllocation() public useAllocation {
        IHorizonStakingExtension.Allocation memory allocation = staking.getAllocation(_allocationId);
        assertEq(allocation.indexer, _allocation.indexer);
        assertEq(allocation.subgraphDeploymentID, _allocation.subgraphDeploymentID);
        assertEq(allocation.tokens, _allocation.tokens);
        assertEq(allocation.createdAtEpoch, _allocation.createdAtEpoch);
        assertEq(allocation.closedAtEpoch, _allocation.closedAtEpoch);
        assertEq(allocation.collectedFees, _allocation.collectedFees);
        assertEq(allocation.__DEPRECATED_effectiveAllocation, _allocation.__DEPRECATED_effectiveAllocation);
        assertEq(allocation.accRewardsPerAllocatedToken, _allocation.accRewardsPerAllocatedToken);
        assertEq(allocation.distributedRebates, _allocation.distributedRebates);
    }

    function testAllocation_GetAllocationData() public useAllocation {
        (address indexer, bytes32 subgraphDeploymentID, uint256 tokens, uint256 accRewardsPerAllocatedToken) = 
            staking.getAllocationData(_allocationId);
        assertEq(indexer, _allocation.indexer);
        assertEq(subgraphDeploymentID, _allocation.subgraphDeploymentID);
        assertEq(tokens, _allocation.tokens);
        assertEq(accRewardsPerAllocatedToken, _allocation.accRewardsPerAllocatedToken);
    }

    function testAllocation_GetAllocationState_Active() public useAllocation {
        IHorizonStakingExtension.AllocationState state = staking.getAllocationState(_allocationId);
        assertEq(uint16(state), uint16(IHorizonStakingExtension.AllocationState.Active));
    }

    function testAllocation_GetAllocationState_Null() public view {
        IHorizonStakingExtension.AllocationState state = staking.getAllocationState(_allocationId);
        assertEq(uint16(state), uint16(IHorizonStakingExtension.AllocationState.Null));
    }

    function testAllocation_IsAllocation() public useAllocation {
        bool isAllocation = staking.isAllocation(_allocationId);
        assertTrue(isAllocation);
    }

    function testAllocation_IsNotAllocation() public view {
        bool isAllocation = staking.isAllocation(_allocationId);
        assertFalse(isAllocation);
    }

    function testCloseAllocation(uint256 tokens) public useIndexer {
        tokens = bound(tokens, 1, MAX_STAKING_TOKENS);
        _storeAllocation(tokens);
        _storeMaxAllocationEpochs();
        _createProvision(subgraphDataServiceLegacyAddress, tokens, 0, 0);

        // Skip 15 epochs
        vm.roll(15);

        staking.closeAllocation(_allocationId, _poi);
        IHorizonStakingExtension.Allocation memory allocation = staking.getAllocation(_allocationId);
        assertEq(allocation.closedAtEpoch, epochManager.currentEpoch());

        // Stake should be updated with rewards
        assertEq(staking.getStake(address(users.indexer)), tokens + ALLOCATIONS_REWARD_CUT);
    }

    function testCloseAllocation_RevertWhen_NotActive() public {
        vm.expectRevert("!active");
        staking.closeAllocation(_allocationId, _poi);
    }

    function testCloseAllocation_RevertWhen_NotIndexer() public useAllocation {
        resetPrank(users.delegator);
        vm.expectRevert("!auth");
        staking.closeAllocation(_allocationId, _poi);
    }

    function testCloseAllocation_AfterMaxEpochs_AnyoneCanClose(uint256 tokens) public useIndexer {
        tokens = bound(tokens, 1, MAX_STAKING_TOKENS);
        _storeAllocation(tokens);
        _storeMaxAllocationEpochs();
        _createProvision(subgraphDataServiceLegacyAddress, tokens, 0, 0);

        // Skip to over the max allocation epochs
        vm.roll(MAX_ALLOCATION_EPOCHS + 2);

        resetPrank(users.delegator);
        staking.closeAllocation(_allocationId, 0x0);
        IHorizonStakingExtension.Allocation memory allocation = staking.getAllocation(_allocationId);
        assertEq(allocation.closedAtEpoch, epochManager.currentEpoch());

        // No rewards distributed
        assertEq(staking.getStake(address(users.indexer)), tokens);
    }

    function testCloseAllocation_RevertWhen_ZeroTokensNotAuthorized() public useIndexer {
        _storeAllocation(0);
        _storeMaxAllocationEpochs();

        // Skip to over the max allocation epochs
        vm.roll(MAX_ALLOCATION_EPOCHS + 2);

        resetPrank(users.delegator);
        vm.expectRevert("!auth");
        staking.closeAllocation(_allocationId, 0x0);
    }
}
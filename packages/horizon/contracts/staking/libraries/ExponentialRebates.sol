// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.26;

import { LibFixedMath } from "../../libraries/LibFixedMath.sol";

/**
 * @title ExponentialRebates library
 * @notice A library to compute query fee rebates using an exponential formula
 * @dev This is only used for backwards compatibility in HorizonStaking, and should
 * be removed after the transition period.
 */
library ExponentialRebates {
    /// @dev Maximum value of the exponent for which to compute the exponential before clamping to zero.
    uint32 private constant MAX_EXPONENT = 15;

    /// @dev The exponential formula used to compute fee-based rewards for
    ///      staking pools in a given epoch. This function does not perform
    ///      bounds checking on the inputs, but the following conditions
    ///      need to be true:
    ///         0 <= alphaNumerator / alphaDenominator <= 1
    ///         0 < lambdaNumerator / lambdaDenominator
    ///      The exponential rebates function has the form:
    ///      `(1 - alpha * exp ^ (-lambda * stake / fees)) * fees`
    /// @param fees Fees generated by indexer in the staking pool.
    /// @param stake Stake attributed to the indexer in the staking pool.
    /// @param alphaNumerator Numerator of `alpha` in the rebates function.
    /// @param alphaDenominator Denominator of `alpha` in the rebates function.
    /// @param lambdaNumerator Numerator of `lambda` in the rebates function.
    /// @param lambdaDenominator Denominator of `lambda` in the rebates function.
    /// @return rewards Rewards owed to the staking pool.
    function exponentialRebates(
        uint256 fees,
        uint256 stake,
        uint32 alphaNumerator,
        uint32 alphaDenominator,
        uint32 lambdaNumerator,
        uint32 lambdaDenominator
    ) external pure returns (uint256) {
        // If alpha is zero indexer gets 100% fees rebate
        int256 alpha = LibFixedMath.toFixed(int32(alphaNumerator), int32(alphaDenominator));
        if (alpha == 0) {
            return fees;
        }

        // No rebates if no fees...
        if (fees == 0) {
            return 0;
        }

        // Award all fees as rebate if the exponent is too large
        int256 lambda = LibFixedMath.toFixed(int32(lambdaNumerator), int32(lambdaDenominator));
        int256 exponent = LibFixedMath.mulDiv(lambda, int256(stake), int256(fees));
        if (LibFixedMath.toInteger(exponent) > int256(uint256(MAX_EXPONENT))) {
            return fees;
        }

        // Compute `1 - alpha * exp ^(-exponent)`
        int256 factor = LibFixedMath.sub(LibFixedMath.one(), LibFixedMath.mul(alpha, LibFixedMath.exp(-exponent)));

        // Weight the fees by the factor
        return LibFixedMath.uintMul(factor, fees);
    }
}

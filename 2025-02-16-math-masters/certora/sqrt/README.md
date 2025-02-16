# Certora Formal Verification for `MathMasters::sqrt`

## Overview

This directory contains the Certora configuration and specification files used to verify the `sqrt` function in `MathMasters.sol`, an arithmetic library for fixed-point operations.

Since `MathMasters.sol` is a library with internal functions, we use `Harness.sol` as a wrapper to expose the functions for verification.

## Files

- **`Sqrt.spec`** – Specification file defining formal verification properties for `sqrt`.
- **`Sqrt.conf`** – Configuration file specifying the verification setup for Certora.

## Running the Verification

To execute the Certora Prover locally, run:
```sh
certoraRun ./certora/sqrt/Sqrt.conf
```

For detailed results, refer to the [Certora Job Report](https://prover.certora.com/output/3325068/79fa9c55a772461daa358c57d90db1d4?anonymousKey=bb1a2a6f0424d7d238e8d066852fd3824fe5b872).


## Verified Property

Running the `sqrt` function directly with the Certora Prover will result in a Path Explosion issue. So, we use the upper halves of the `sqrt` function and the `Base_Test::solmateSqrt` function. They should return the same result when passing the same input.

- Property tested: The `sqrt` function upper half must return the same result as the `Base_Test::solmateSqrt` function upper half.

## Issue Found

The following input value breaks the square root invariant, as identified by Certora:

```
uint256 x = 0xffffffffffffffffffffff;
```

## Modifications

For any updates or modifications to the verification, adjust `Sqrt.spec` and `Sqrt.conf` accordingly.

![LokapalBanner](https://github.com/user-attachments/assets/5509e1f8-9f31-4141-8975-02132a1ba63e)

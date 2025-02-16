# Certora Formal Verification for `MathMasters::mulWadUp`

## Overview

This directory contains the Certora configuration and specification files used to verify the `mulWadUp` function in `MathMasters.sol`, an arithmetic library for fixed-point operations.

Since `MathMasters.sol` is a library with internal functions, we use `Harness.sol` as a wrapper to expose the functions for verification.

## Files

- **`Harness.sol`** – Wrapper contract exposing internal functions of `MathMasters.sol` as `external` for Certora verification.
- **`MulWadUp.spec`** – Specification file defining formal verification properties for `mulWadUp`.
- **`MulWadUp.conf`** – Configuration file specifying the verification setup for Certora.

## Running the Verification

To execute the Certora Prover locally, run:
```sh
certoraRun ./certora/MulWadUp.conf
```

For detailed results, refer to the [Certora Job Report](https://prover.certora.com/output/3325068/7e410377b5334388aded05266976410e?anonymousKey=e3f06fd53553bbc521ccebff32e252b5319153aa).


## Verified Property

- Correct Rounding Up: The `mulWadUp` function must round up properly.

## Issue Found

The following input values break the rounding-up invariant, as identified by Certora:

```
uint256 x = 0xde0b6b3a7640000;
uint256 y = 0xde0b6b3a7640000;
```

## Modifications

For any updates or modifications to the verification, adjust `MulWadUp.spec` and `MulWadUp.conf` accordingly.

![LokapalBanner](https://github.com/user-attachments/assets/5509e1f8-9f31-4141-8975-02132a1ba63e)

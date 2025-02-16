# Certora Formal Verification for `MathMasters.sol`

## Overview

This directory contains the Certora configuration and specification files used to verify the `MulWadUp` and `Sqrt` functions in `MathMasters.sol`, an arithmetic library for fixed-point operations.

Since `MathMasters.sol` is a library with internal functions, we use `Harness.sol` as a wrapper to expose the functions for verification.

## Notice

Each folder contains the same `Harness.sol` file. To avoid duplication, you can consolidate all `.conf` and `.spec` files into a single folder and use a single harness for both verifications.

![LokapalBanner](https://github.com/user-attachments/assets/5509e1f8-9f31-4141-8975-02132a1ba63e)

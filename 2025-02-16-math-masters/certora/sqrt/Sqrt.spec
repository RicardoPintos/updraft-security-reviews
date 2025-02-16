//
// Verification of Sqrt
//

methods {
    function mathMastersTopHalf(uint256) external returns uint256 envfree;
    function solmateTopHalf(uint256) external returns uint256 envfree;
}


rule solmateTopHalfMatchesMathMastersTopHalf(uint256 x) {
    assert(mathMastersTopHalf(x) == solmateTopHalf(x));
}


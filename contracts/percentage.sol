// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library Percentage {
    // funciton to set a value accordig to the percentage:
    function percentage(
        uint total,
        uint _percentage
    ) internal pure returns (uint) {
        uint all = total * _percentage;
        return all / 100;
    }
}

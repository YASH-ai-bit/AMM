//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Test} from "forge-std/Test.sol";
import {DeployAMM} from "../../script/DeployAMM.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {AMM} from "../../src/AMM.sol";

contract Handler is Test {
    AMM amm;
    ERC20Mock token1;
    ERC20Mock token2;
    uint256 public s_initialProduct;

    constructor(AMM _amm) {
        amm = _amm;
        s_initialProduct = amm.getReserve1() * amm.getReserve2();
    }

    function addLiquidity(uint256 amount1, uint256 amount2) public {
        amm.addLiquidity(amount1, amount2);
    }

    function removeLiquidity(uint256 shares) public {
        amm.removeLiquidity(shares);
    }

    function swap2to1(uint256 amountIn) public {
        amm.swap2_1(amountIn);
    }

    function swap1to2(uint256 amountIn) public {
        amm.swap1_2(amountIn);
    }

}

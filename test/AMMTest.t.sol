//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {AMM} from "../src/AMM.sol";
import {DeployAMM} from "../script/DeployAMM.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract AMMTest is Test {
    AMM amm;
    DeployAMM deployer;
    ERC20Mock token1;
    ERC20Mock token2;
    address public USER = makeAddr("User");
    uint256 public constant INITIAL_BALANCE = 5000 ether;
    uint256 public constant AMT_T1 = 100 ether;
    uint256 public constant AMT_T2 = 100 ether;

    function setUp() public {
        deployer = new DeployAMM();
        (amm, token1, token2) = deployer.run();

        token1.mint(address(this), INITIAL_BALANCE);
        token2.mint(address(this), INITIAL_BALANCE);

        token1.mint(USER, INITIAL_BALANCE);
        token2.mint(USER, INITIAL_BALANCE);

        token1.approve(address(amm), type(uint256).max);
        token2.approve(address(amm), type(uint256).max);

        vm.startPrank(USER);
        token1.approve(address(amm), type(uint256).max);
        token2.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        amm.initialLiquidity(AMT_T1, AMT_T2);
    }

    ///////////////////INITIAL_LIQUIDITY///////////////
    function testInitialLiquidity() public {
        vm.prank(USER);
        assert((amm.getReserve1() + amm.getReserve2()) == (AMT_T1 + AMT_T2));
        assert(amm.getShares(address(this)) == amm._sqrt(AMT_T1 * AMT_T2));
    }

    ///////////////ADDING LIQUIDITY///////////////////
    function testAddLiquidity() public {
        vm.prank(USER);
        amm.addLiquidity(AMT_T1, AMT_T2);
        assert((amm.getReserve1() + amm.getReserve2()) == 2 * (AMT_T1 + AMT_T2));
        console2.log(amm.getShares(USER));
        assert((amm.getShares(USER)) == 100 ether);
    }

    function testRevertIfProductRuleFails() public {
        vm.prank(USER);
        console2.log(amm.getReserve1() * AMT_T2);
        console2.log(amm.getReserve2() * AMT_T1);
        vm.expectRevert(AMM.AMM__ProductRuleFailed.selector);
        amm.addLiquidity((AMT_T1 + 17), AMT_T2);
    }

    ///////////////REMOVING LIQUIDITY///////////////////
    function testRemoveLiquidity() public {
        vm.prank(USER);
        (uint256 shares) = amm.addLiquidity(AMT_T1, AMT_T2);

        uint256 justBeforeRemovingLiquidity_token1 = amm.getReserve1();
        uint256 justBeforeRemovingLiquidity_token2 = amm.getReserve2();

        (uint256 token1_out, uint256 token2_out) = amm.removeLiquidity(shares);
        assert(token1_out == 100 ether);
        assert(token2_out == 100 ether);
        assert(amm.getReserve1() == (justBeforeRemovingLiquidity_token1 - shares));
        assert(amm.getReserve2() == (justBeforeRemovingLiquidity_token2 - shares));
    }

    /////////////// SWAP ///////////////////
    function testSwap2_1() public {
        vm.prank(USER);
        (uint256 amountOut) = amm.swap2_1(AMT_T2);

        assert(amm.getReserve2() == 200 ether);
        assert(amountOut == ((token1.balanceOf(USER) - INITIAL_BALANCE)));
        assert(amm.getReserve1() == (AMT_T2 - ((token1.balanceOf(USER) - INITIAL_BALANCE))));
    }

    function testRevertIfSwapAmountIsZero() public {
        vm.prank(USER);
        vm.expectRevert(AMM.AMM__AmountZeroOrNegative.selector);
        amm.swap1_2(0);
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployAMM} from "../../script/DeployAMM.s.sol";
import {AMM} from "../../src/AMM.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is Test {
    AMM amm;
    DeployAMM deployer;
    ERC20Mock token1;
    ERC20Mock token2;
    Handler handler;

    address public USER = makeAddr("User");
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public  AMOUNT1 = 100 ether ;
    uint256 public  AMOUNT2 = 100 ether ;

    function setUp() public {
        deployer = new DeployAMM();
        (amm, token1, token2) = deployer.run();

        handler = new Handler(amm);

        token1.mint(address(this), INITIAL_BALANCE);
        token2.mint(address(this), INITIAL_BALANCE);

        token1.mint(USER, INITIAL_BALANCE);
        token2.mint(USER, INITIAL_BALANCE);

        token1.approve(address(amm), type(uint256).max);
        token2.approve(address(amm), type(uint256).max);

        // vm.startPrank(USER);
        // token1.approve(address(amm), type(uint256).max);
        // token2.approve(address(amm), type(uint256).max);
        // vm.stopPrank();

        targetContract(address(handler));
        amm.initialLiquidity(AMOUNT1, AMOUNT2);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = Handler.addLiquidity.selector;
        selectors[1] = Handler.removeLiquidity.selector;
        selectors[2] = Handler.swap1to2.selector;
        selectors[3] = Handler.swap2to1.selector;

        targetSelector(
            FuzzSelector({
                addr: address(handler),
                selectors: selectors
            })
        );
    }

    function invariant_testProductRuleShouldAlwaysFollow() public view {
        uint256 reserve1After = amm.getReserve1();
        uint256 reserve2After = amm.getReserve2();
        uint256 productAfter = reserve1After * reserve2After ;

        assert(productAfter >= handler.s_initialProduct());
    }

    function invariant_testAfterSwapsOverallValueShouldBeSame() public view {
        uint256 reserve1 = amm.getReserve1();
        uint256 reserve2 = amm.getReserve2();
        uint256 totalValue = reserve1 + reserve2 ;  //a rough estimate of total value of tokens in pool

        uint256 feeFactor = 995 ;
        uint256 expectedValue = (reserve1 * reserve2) * (feeFactor / 1000); //baseline invariant

        assertGe(totalValue, expectedValue, "Total Value draining too much - swap values / fees are  inappropriate");
    }
}


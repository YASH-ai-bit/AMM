//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {AMM} from "../src/AMM.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DeployAMM is Script {
    function run() external returns (AMM amm, ERC20Mock m_token1, ERC20Mock m_token2) {
        vm.startBroadcast();
        m_token1 = new ERC20Mock();
        m_token2 = new ERC20Mock();

        amm = new AMM(address(m_token1), address(m_token2));
        vm.stopBroadcast();
    }
}

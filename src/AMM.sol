//SPDX-License-Identifer: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AMM is Ownable, ReentrancyGuard {
    /////////////ERRORS/////////////
    error AMM__ProductRuleFailed();
    error AMM__AmountZeroOrNegative();
    error AMM__InvalidToken();
    error AMM_ZeroShares();

    ////////////STATE VARIABLES//////////
    IERC20 public immutable token1;
    IERC20 public immutable token2;

    uint256 public reserve1;
    uint256 public reserve2;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    constructor(address _token1, address _token2) Ownable(msg.sender) {
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
    }

    function _mint(address _to, uint256 _amount) public {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    function _burn(address _from, uint256 _amount) public {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    function _update(uint256 _reserve1, uint256 _reserve2) public {
        reserve1 = _reserve1;
        reserve2 = _reserve2;
    }

    /**
     * @dev Initializes the liquidity pool
     */
    function initialLiquidity(uint256 _amount1, uint256 _amount2) public {
        addLiquidity(_amount1, _amount2);
    }

    /**
     * @dev when user wants to add token into the pool
     * @notice user mints the LPtokens(shares) using formula S = (dx / x) * T
     */
    function addLiquidity(uint256 _amount1, uint256 _amount2) public returns (uint256 _shares) {
        //add tokens
        bool success1 = token1.transferFrom(msg.sender, address(this), _amount1);
        bool success2 = token2.transferFrom(msg.sender, address(this), _amount2);
        if (!success1 || !success2) revert AMM__InvalidToken();

        //how many tokens to add i.e. dx, dy == ?  --> x / y = dx / dy  => x * dy = y * dx
        //checking the AMM Constant Product Rule :
        if (reserve1 > 0 || reserve2 > 0) {
            if (reserve1 * _amount2 != reserve2 * _amount1) {
                revert AMM__ProductRuleFailed();
            }
        }

        //mint shares  --> S = (dx / x) * T
        //function for liquidity => f(x, y) = sqrt(x * y)
        //function minimum to return the minmum number of tokens required to maintain the liquidity pool constraint
        if (totalSupply == 0) {
            _shares = _sqrt(_amount1 * _amount2);
        } else {
            _shares = _minimum((_amount1 * totalSupply) / reserve1, (_amount2 * totalSupply) / reserve2);
        }
        if (_shares == 0) {
            revert AMM_ZeroShares();
        }
        _mint(msg.sender, _shares);
        _update(token1.balanceOf(address(this)), token2.balanceOf(address(this)));
    }

    /**
     * @dev when the liquidity provider wants to remove his shares from the pool
     * @notice shares are burnt and tokens come out using formula --> dx = x * (S / T) , same for both tokens
     */
    function removeLiquidity(uint256 _shares) public nonReentrant returns (uint256 _amount1, uint256 _amount2) {
        if (_shares == 0) {
            revert AMM_ZeroShares();
        }

        // calculating amount of tokens for withdrawal
        uint256 token1_out = (reserve1 * _shares) / totalSupply;
        uint256 token2_out = (reserve2 * _shares) / totalSupply;

        token1.transfer(msg.sender, token1_out);
        token2.transfer(msg.sender, token2_out);

        _burn(msg.sender, _shares);
        _update(token1.balanceOf(address(this)), token2.balanceOf(address(this)));

        return (token1_out, token2_out);
    }

    /**
     * @dev this function is called when we exchange token1 for token2 i.e. token1 in and token2 out
     * @notice users need to pay a little fess to liquidity providers, here 0.5%
     */
    function swap1_2(uint256 _amountIn) public returns (uint256 _amountOut) {
        if (address(token1) == address(0) || address(token2) == address(0)) {
            revert AMM__InvalidToken();
        }

        if (_amountIn == 0 || _amountIn < 0) {
            revert AMM__AmountZeroOrNegative();
        }
        token1.transferFrom(msg.sender, address(this), _amountIn);

        // cutting 0.5% fees for LPs (Liquidity Providers)
        uint256 amountInWithFee = (_amountIn * 995) / 1000;

        //since x / y = (x + dx) / (y + dy)  --> dy = y * dx / (x + dx)  --> condition for AMM
        _amountOut = (reserve2 * amountInWithFee) / (amountInWithFee + reserve1);
        token2.transfer(msg.sender, _amountOut);

        _update(token1.balanceOf(address(this)), token2.balanceOf(address(this)));

        return _amountOut;
    }

    /**
     * @dev this function is called when we exchange token2 for token1 i.e. token2 in and token1 out
     * @notice users need to pay a little fess to liquidity providers, here 0.5%
     */
    function swap2_1(uint256 _amountIn) public returns (uint256 _amountOut) {
        if (address(token1) == address(0) || address(token2) == address(0)) {
            revert AMM__InvalidToken();
        }

        if (_amountIn == 0 || _amountIn < 0) {
            revert AMM__AmountZeroOrNegative();
        }
        token2.transferFrom(msg.sender, address(this), _amountIn);

        // cutting 0.5% fees for LPs (Liquidity Providers)
        uint256 amountInWithFee = (_amountIn * 995) / 1000;

        //since x / y = (x + dx) / (y + dy)  --> dy = y * dx / (x + dx)  --> condition for AMM
        _amountOut = (reserve1 * amountInWithFee) / (amountInWithFee + reserve2);
        token1.transfer(msg.sender, _amountOut);

        _update(token1.balanceOf(address(this)), token2.balanceOf(address(this)));

        return _amountOut;
    }

    //////////////////////////HELPER FUNCTIONS//////////////////////////
    function _sqrt(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _minimum(uint256 x, uint256 y) public pure returns (uint256) {
        return x <= y ? x : y;
    }

    //GETTER FUNCTIONS
    function getReserve1() external view returns (uint256) {
        return reserve1;
    }

    function getReserve2() external view returns (uint256) {
        return reserve2;
    }

    function getShares(address user) external view returns (uint256) {
        return balanceOf[user];
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }
}

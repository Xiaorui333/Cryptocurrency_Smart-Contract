pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "contracts/periphery/test/TestERC20.sol";
import "contracts/core/UniswapV2Factory.sol";
import "contracts/periphery/test/WETH9.sol";
import "contracts/periphery/UniswapV2Router02.sol";

contract TestSetup is Test {


    function testPairs() public {
        address deployer = address(0x123);

        UniswapV2Factory factory = new UniswapV2Factory(deployer);

        WETH9 weth = new WETH9();
        UniswapV2Router02 router = new UniswapV2Router02(address(factory), address(weth));

        // Deploy test tokens.
        TestERC20 tokenA = new TestERC20("TokenA", "TKA", 18);
        TestERC20 tokenB = new TestERC20("TokenB", "TKB", 18);

        address pairAddress = factory.createPair(address(tokenA), address(tokenB));

        uint256 len = factory.getAllPairsWithTokensLength();
        for (uint256 i = 0; i < len; i++) {
            (address a, address b, address c) = factory.getTriple(i);
            console.log("Triple", i);
            console.log(a, b, c);
        }
    }
}
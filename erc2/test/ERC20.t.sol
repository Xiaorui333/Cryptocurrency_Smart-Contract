// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "../src/ERC20.sol";

contract ERC20Test is Test {

    function setUp() public {
    }

    function test_totalSupply00() public {
        ERC20 erc20 = new ERC20(100);
        assertEq(erc20.totalSupply(), 100);
    }

    function test_balanceOf0() public {
        address alice = address(0x1);

        ERC20 erc20 = new ERC20(100);
        assertEq(erc20.balanceOf(alice), 0);
    }

    function test_balanceOf1() public {
        address bob = address(0x2); // owner of the erc20

        vm.prank(bob);
        ERC20 erc20 = new ERC20(100);
        assertEq(erc20.balanceOf(bob), 100);
    }

    function test_transfer0() public {
        address alice = address(0x1);

        address bob = address(0x2); // owner of the erc20

        vm.prank(bob);
        ERC20 erc20 = new ERC20(100);

        // bob transfer to alice 50 tokens
        vm.prank(bob);
        erc20.transfer(alice, 50);

        assertEq(erc20.balanceOf(alice), 50);
        assertEq(erc20.balanceOf(bob), 50);
    }

    function test_transfer1() public {
        address alice = address(0x1);

        address bob = address(0x2); // owner of the erc20

        vm.prank(bob);
        ERC20 erc20 = new ERC20(100);

        // bob transfer to alice 50 tokens
        vm.prank(bob);
        vm.expectRevert();
        erc20.transfer(alice, 101);
    }

    function test_oog() public {

    }
}

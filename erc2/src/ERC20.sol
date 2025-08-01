pragma solidity ^0.8.0;

/*
function balanceOf(address): returns the # tokens for an address

//  transfer from the sender to the receiver value # of token
function transfer(address receiver, uint256 value) public returns (bool success)

// transfer from the sender to the receiver value # of token
function transferFrom(address from, address to, uint256 value) public returns (bool success)

// give spender permission to transfer up to value tokens on sender's behalf
function approve(address spender, uint256 value) public returns (bool success)

// read-only: returns the number of tokens that owner has approved for spender.
function allowance(address _owner, address _spender) public view returns (uint256 remaining)

// returns the total number of tokens in the contract
function totalSupply() public view returns (uint256)

*/
import {console} from "forge-std/Test.sol";


contract ERC20 {

    uint256 public totalSupply;
    mapping(address => uint256) private balances;

    constructor(uint256 _tokenSupply) {
        totalSupply = _tokenSupply;
        balances[msg.sender] = totalSupply;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return balances[owner];
    }

    function transfer(address receiver, uint256 value) public returns (bool) {
        require(receiver != address(0));
        balances[msg.sender] = balances[msg.sender] - value;
        balances[receiver] = balances[receiver] + value;
        return true;
    }
}
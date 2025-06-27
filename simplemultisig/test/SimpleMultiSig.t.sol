// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleMultiSig} from "../src/SimpleMultiSig.sol";

// Mock ERC20 contract for testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;
    string public name = "MockToken";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 _totalSupply) {
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

// Contract that can receive ETH and tokens
contract TestReceiver {
    uint256 public receivedValue;
    bytes public receivedData;
    bool public shouldRevert;

    function setRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function receiveCall(uint256 value) external payable {
        require(!shouldRevert, "TestReceiver: forced revert");
        receivedValue = value;
        receivedData = msg.data;
    }

    receive() external payable {
        require(!shouldRevert, "TestReceiver: forced revert");
        receivedValue = msg.value;
    }
}

contract SimpleMultiSigTest is Test {
    address private alice;
    address private bob;
    address private charlie;
    address private dave;
    address[] private owners;

    uint256 private alicePrivateKey;
    uint256 private bobPrivateKey;
    uint256 private charliePrivateKey;

    SimpleMultiSig public multisig;
    MockERC20 public token;
    TestReceiver public receiver;

    uint256 constant CHAIN_ID = 1337;

    function setUp() public {
        // Set up private keys and derive addresses
        alicePrivateKey = 0x1111;
        bobPrivateKey = 0x2222;
        charliePrivateKey = 0x3333;

        alice = vm.addr(alicePrivateKey);
        bob = vm.addr(bobPrivateKey);
        charlie = vm.addr(charliePrivateKey);
        dave = address(0x4444);  // Not an owner

        // Ensure addresses are in ascending order for multisig requirements
        address[] memory tempOwners = new address[](3);
        tempOwners[0] = alice;
        tempOwners[1] = bob;
        tempOwners[2] = charlie;

        // Sort addresses
        for (uint i = 0; i < tempOwners.length - 1; i++) {
            for (uint j = 0; j < tempOwners.length - i - 1; j++) {
                if (tempOwners[j] > tempOwners[j + 1]) {
                    address temp = tempOwners[j];
                    tempOwners[j] = tempOwners[j + 1];
                    tempOwners[j + 1] = temp;
                }
            }
        }

        owners = tempOwners;

        multisig = new SimpleMultiSig(2, owners, CHAIN_ID);
        token = new MockERC20(1000000 * 10**18);
        receiver = new TestReceiver();

        // Fund the multisig with ETH and tokens
        vm.deal(address(multisig), 10 ether);
        token.transfer(address(multisig), 100000 * 10**18);
    }

    // ===== CONSTRUCTOR TESTS =====

    function test_constructor_ValidOwners() public view {
        assertEq(multisig.threshold(), 2);
        assertEq(multisig.ownersArr(0), owners[0]);
        assertEq(multisig.ownersArr(1), owners[1]);
        assertEq(multisig.ownersArr(2), owners[2]);
        assertEq(multisig.nonce(), 0);
    }

    function test_constructor_RevertIfThresholdZero() public {
        vm.expectRevert();
        new SimpleMultiSig(0, owners, CHAIN_ID);
    }

    function test_constructor_RevertIfThresholdTooHigh() public {
        vm.expectRevert();
        new SimpleMultiSig(4, owners, CHAIN_ID);
    }

    function test_constructor_RevertIfTooManyOwners() public {
        address[] memory tooManyOwners = new address[](11);
        for (uint i = 0; i < 11; i++) {
            tooManyOwners[i] = address(uint160(i + 1));
        }
        vm.expectRevert();
        new SimpleMultiSig(5, tooManyOwners, CHAIN_ID);
    }


    // ===== SIGNATURE HELPER FUNCTIONS =====

    function getTransactionHash(
        address destination,
        uint256 value,
        bytes memory data,
        uint256 nonce,
        address executor,
        uint256 gasLimit
    ) internal view returns (bytes32) {
        bytes32 txInputHash = keccak256(abi.encode(
            0x3ee892349ae4bbe61dce18f95115b5dc02daf49204cc602458cd4c1f540d56d7, // TXTYPE_HASH
            destination,
            value,
            keccak256(data),
            nonce,
            executor,
            gasLimit
        ));

        bytes32 domainSeparator = keccak256(abi.encode(
            0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472, // EIP712DOMAINTYPE_HASH
            0xb7a0bfa1b79f2443f4d73ebb9259cddbcd510b18be6fc4da7d1aa7b1786e73e6, // NAME_HASH
            0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // VERSION_HASH
            CHAIN_ID,
            address(multisig),
            0x251543af6a222378665a76fe38dbceae4871a070b7fdaf5c6c30cf758dc33cc0  // SALT
        ));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, txInputHash));
    }

    function signTransaction(
        uint256 privateKey,
        address destination,
        uint256 value,
        bytes memory data,
        uint256 nonce,
        address executor,
        uint256 gasLimit
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 hash = getTransactionHash(destination, value, data, nonce, executor, gasLimit);
        return vm.sign(privateKey, hash);
    }

    function getSignedTransaction(
        uint256[] memory privateKeys,
        address destination,
        uint256 value,
        bytes memory data,
        uint256 nonce,
        address executor,
        uint256 gasLimit
    ) internal view returns (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) {
        sigV = new uint8[](privateKeys.length);
        sigR = new bytes32[](privateKeys.length);
        sigS = new bytes32[](privateKeys.length);

        for (uint i = 0; i < privateKeys.length; i++) {
            (sigV[i], sigR[i], sigS[i]) = signTransaction(
                privateKeys[i], destination, value, data, nonce, executor, gasLimit
            );
        }
    }

    // ===== BASIC EXECUTION TESTS =====

    function test_execute_BasicETHTransfer() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), 100000);

        uint256 balanceBefore = recipient.balance;
        uint256 multisigBalanceBefore = address(multisig).balance;

        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);

        assertEq(recipient.balance, balanceBefore + amount);
        assertEq(address(multisig).balance, multisigBalanceBefore - amount);
        assertEq(multisig.nonce(), 1);
    }

    function test_execute_CallContract() public {
        bytes memory data = abi.encodeWithSignature("receiveCall(uint256)", 42);

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, address(receiver), 0, data, 0, address(0), 100000);

        multisig.execute(sigV, sigR, sigS, address(receiver), 0, data, address(0), 100000);

        assertEq(receiver.receivedValue(), 42);
        assertEq(multisig.nonce(), 1);
    }

    function test_execute_ERC20Transfer() public {
        address recipient = address(0x9999);
        uint256 amount = 1000 * 10**18;
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", recipient, amount);

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, address(token), 0, data, 0, address(0), 100000);

        uint256 balanceBefore = token.balanceOf(recipient);
        uint256 multisigBalanceBefore = token.balanceOf(address(multisig));

        multisig.execute(sigV, sigR, sigS, address(token), 0, data, address(0), 100000);

        assertEq(token.balanceOf(recipient), balanceBefore + amount);
        assertEq(token.balanceOf(address(multisig)), multisigBalanceBefore - amount);
        assertEq(multisig.nonce(), 1);
    }

    function test_execute_WithSpecificExecutor() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";
        address executor = alice;

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, executor, 100000);

        vm.prank(executor);
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, executor, 100000);

        assertEq(multisig.nonce(), 1);
    }

    // ===== SIGNATURE VALIDATION TESTS =====

    function test_execute_RevertIfInsufficientSignatures() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](1); // Only 1 signature, need 2
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), 100000);

        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
    }

    function test_execute_RevertIfSignatureArraysMismatch() public {
        uint8[] memory sigV = new uint8[](2);
        bytes32[] memory sigR = new bytes32[](1); // Mismatched length
        bytes32[] memory sigS = new bytes32[](2);

        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, address(0x9999), 1 ether, "", address(0), 100000);
    }

    function test_execute_RevertIfNonOwnerSignature() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = 0x9999; // Not an owner's private key

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), 100000);

        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
    }

    function test_execute_RevertIfSignaturesNotSorted() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        // Get signatures in wrong order (should be sorted by recovered address)
        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[1]); // Higher address first
        privateKeys[1] = getPrivateKeyForAddress(owners[0]); // Lower address second

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), 100000);

        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
    }

    function test_execute_RevertIfWrongExecutor() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";
        address executor = alice;

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, executor, 100000);

        vm.prank(bob); // Wrong executor
        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, executor, 100000);
    }

    function test_execute_RevertIfWrongNonce() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        // Sign with wrong nonce (should be 0, using 1)
        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 1, address(0), 100000);

        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
    }

    // ===== NONCE TESTS =====

    function test_execute_NonceIncrementsCorrectly() public {
        address recipient = address(0x9999);
        uint256 amount = 0.5 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        // First transaction (nonce 0)
        (uint8[] memory sigV1, bytes32[] memory sigR1, bytes32[] memory sigS1) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), 100000);

        multisig.execute(sigV1, sigR1, sigS1, recipient, amount, data, address(0), 100000);
        assertEq(multisig.nonce(), 1);

        // Second transaction (nonce 1)
        (uint8[] memory sigV2, bytes32[] memory sigR2, bytes32[] memory sigS2) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 1, address(0), 100000);

        multisig.execute(sigV2, sigR2, sigS2, recipient, amount, data, address(0), 100000);
        assertEq(multisig.nonce(), 2);
    }

    function test_execute_RevertIfReplayAttack() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), 100000);

        // First execution should succeed
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
        assertEq(multisig.nonce(), 1);

        // Second execution with same signatures should fail (wrong nonce)
        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
    }

    // ===== ERC20 INTERACTION TESTS =====

    function test_execute_ERC20Approve() public {
        address spender = address(0x9999);
        uint256 amount = 5000 * 10**18;
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", spender, amount);

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, address(token), 0, data, 0, address(0), 100000);

        multisig.execute(sigV, sigR, sigS, address(token), 0, data, address(0), 100000);

        assertEq(token.allowance(address(multisig), spender), amount);
        assertEq(multisig.nonce(), 1);
    }

    function test_execute_MultipleERC20Operations() public {
        address recipient1 = address(0x1111);
        address recipient2 = address(0x2222);
        uint256 amount1 = 1000 * 10**18;
        uint256 amount2 = 2000 * 10**18;

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        // First transfer
        bytes memory data1 = abi.encodeWithSignature("transfer(address,uint256)", recipient1, amount1);
        (uint8[] memory sigV1, bytes32[] memory sigR1, bytes32[] memory sigS1) =
                        getSignedTransaction(privateKeys, address(token), 0, data1, 0, address(0), 100000);

        multisig.execute(sigV1, sigR1, sigS1, address(token), 0, data1, address(0), 100000);
        assertEq(token.balanceOf(recipient1), amount1);
        assertEq(multisig.nonce(), 1);

        // Second transfer
        bytes memory data2 = abi.encodeWithSignature("transfer(address,uint256)", recipient2, amount2);
        (uint8[] memory sigV2, bytes32[] memory sigR2, bytes32[] memory sigS2) =
                        getSignedTransaction(privateKeys, address(token), 0, data2, 1, address(0), 100000);

        multisig.execute(sigV2, sigR2, sigS2, address(token), 0, data2, address(0), 100000);
        assertEq(token.balanceOf(recipient2), amount2);
        assertEq(multisig.nonce(), 2);
    }

    // ===== RECEIVE FUNCTION TEST =====

    function test_receive_ETH() public {
        uint256 amount = 5 ether;
        uint256 balanceBefore = address(multisig).balance;

        vm.deal(address(this), amount);
        payable(address(multisig)).transfer(amount);

        assertEq(address(multisig).balance, balanceBefore + amount);
    }

    // ===== EDGE CASES =====

    function test_execute_EmptyData() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), 100000);

        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
        assertEq(multisig.nonce(), 1);
    }

    function test_execute_ZeroValue() public {
        bytes memory data = abi.encodeWithSignature("receiveCall(uint256)", 123);

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, address(receiver), 0, data, 0, address(0), 100000);

        multisig.execute(sigV, sigR, sigS, address(receiver), 0, data, address(0), 100000);
        assertEq(receiver.receivedValue(), 123);
        assertEq(multisig.nonce(), 1);
    }

    function test_execute_MaxThresholdSignatures() public {
        // Create multisig that requires all 3 signatures
        SimpleMultiSig maxMultisig = new SimpleMultiSig(3, owners, CHAIN_ID);
        vm.deal(address(maxMultisig), 10 ether);

        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](3);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);
        privateKeys[2] = getPrivateKeyForAddress(owners[2]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransactionForMultisig(maxMultisig, privateKeys, recipient, amount, data, 0, address(0), 100000);

        maxMultisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
        assertEq(maxMultisig.nonce(), 1);
        assertEq(recipient.balance, amount);
    }

    // ===== HELPER FUNCTIONS =====

    function getPrivateKeyForAddress(address addr) internal view returns (uint256) {
        if (addr == alice) return alicePrivateKey;
        if (addr == bob) return bobPrivateKey;
        if (addr == charlie) return charliePrivateKey;
        revert("Unknown address");
    }

    function getSignedTransactionForMultisig(
        SimpleMultiSig multisigContract,
        uint256[] memory privateKeys,
        address destination,
        uint256 value,
        bytes memory data,
        uint256 nonce,
        address executor,
        uint256 gasLimit
    ) internal pure returns (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) {
        bytes32 txInputHash = keccak256(abi.encode(
            0x3ee892349ae4bbe61dce18f95115b5dc02daf49204cc602458cd4c1f540d56d7,
            destination,
            value,
            keccak256(data),
            nonce,
            executor,
            gasLimit
        ));

        bytes32 domainSeparator = keccak256(abi.encode(
            0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472,
            0xb7a0bfa1b79f2443f4d73ebb9259cddbcd510b18be6fc4da7d1aa7b1786e73e6,
            0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6,
            CHAIN_ID,
            address(multisigContract),
            0x251543af6a222378665a76fe38dbceae4871a070b7fdaf5c6c30cf758dc33cc0
        ));

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, txInputHash));

        sigV = new uint8[](privateKeys.length);
        sigR = new bytes32[](privateKeys.length);
        sigS = new bytes32[](privateKeys.length);

        for (uint i = 0; i < privateKeys.length; i++) {
            (sigV[i], sigR[i], sigS[i]) = vm.sign(privateKeys[i], hash);
        }
    }

    // ===== FUZZ TESTS =====

    function testFuzz_execute_ETHTransfer(uint256 amount) public {
        // Bound amount to reasonable range
        amount = bound(amount, 1 wei, address(multisig).balance);

        address recipient = address(0x9999);
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), 100000);

        uint256 balanceBefore = recipient.balance;
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);

        assertEq(recipient.balance, balanceBefore + amount);
        assertEq(multisig.nonce(), 1);
    }

    function testFuzz_execute_ERC20Transfer(uint256 amount) public {
        // Bound amount to available balance
        amount = bound(amount, 1, token.balanceOf(address(multisig)));

        address recipient = address(0x9999);
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", recipient, amount);

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, address(token), 0, data, 0, address(0), 100000);

        uint256 balanceBefore = token.balanceOf(recipient);
        multisig.execute(sigV, sigR, sigS, address(token), 0, data, address(0), 100000);

        assertEq(token.balanceOf(recipient), balanceBefore + amount);
        assertEq(multisig.nonce(), 1);
    }

    function testFuzz_execute_WithDifferentGasLimits(uint256 gasLimit) public {
        gasLimit = bound(gasLimit, 21000, 1000000); // Reasonable gas range

        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), gasLimit);

        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), gasLimit);
        assertEq(multisig.nonce(), 1);
    }

    // ===== INTEGRATION TESTS =====

    function test_integration_ComplexERC20Workflow() public {
        address spender = address(0x1111);
        address finalRecipient = address(0x2222);
        uint256 approveAmount = 5000 * 10**18;
        uint256 transferAmount = 3000 * 10**18;

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        // Step 1: Approve spender
        bytes memory approveData = abi.encodeWithSignature("approve(address,uint256)", spender, approveAmount);
        (uint8[] memory sigV1, bytes32[] memory sigR1, bytes32[] memory sigS1) =
                        getSignedTransaction(privateKeys, address(token), 0, approveData, 0, address(0), 100000);

        multisig.execute(sigV1, sigR1, sigS1, address(token), 0, approveData, address(0), 100000);
        assertEq(token.allowance(address(multisig), spender), approveAmount);
        assertEq(multisig.nonce(), 1);

        // Step 2: Transfer tokens directly
        bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", finalRecipient, transferAmount);
        (uint8[] memory sigV2, bytes32[] memory sigR2, bytes32[] memory sigS2) =
                        getSignedTransaction(privateKeys, address(token), 0, transferData, 1, address(0), 100000);

        uint256 balanceBefore = token.balanceOf(finalRecipient);
        multisig.execute(sigV2, sigR2, sigS2, address(token), 0, transferData, address(0), 100000);

        assertEq(token.balanceOf(finalRecipient), balanceBefore + transferAmount);
        assertEq(multisig.nonce(), 2);
    }

    function test_integration_MixedETHAndTokenTransfers() public {
        address ethRecipient = address(0x1111);
        address tokenRecipient = address(0x2222);
        uint256 ethAmount = 2 ether;
        uint256 tokenAmount = 1500 * 10**18;

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        // Transaction 1: Send ETH
        (uint8[] memory sigV1, bytes32[] memory sigR1, bytes32[] memory sigS1) =
                        getSignedTransaction(privateKeys, ethRecipient, ethAmount, "", 0, address(0), 100000);

        uint256 ethBalanceBefore = ethRecipient.balance;
        multisig.execute(sigV1, sigR1, sigS1, ethRecipient, ethAmount, "", address(0), 100000);
        assertEq(ethRecipient.balance, ethBalanceBefore + ethAmount);
        assertEq(multisig.nonce(), 1);

        // Transaction 2: Send tokens
        bytes memory tokenData = abi.encodeWithSignature("transfer(address,uint256)", tokenRecipient, tokenAmount);
        (uint8[] memory sigV2, bytes32[] memory sigR2, bytes32[] memory sigS2) =
                        getSignedTransaction(privateKeys, address(token), 0, tokenData, 1, address(0), 100000);

        uint256 tokenBalanceBefore = token.balanceOf(tokenRecipient);
        multisig.execute(sigV2, sigR2, sigS2, address(token), 0, tokenData, address(0), 100000);
        assertEq(token.balanceOf(tokenRecipient), tokenBalanceBefore + tokenAmount);
        assertEq(multisig.nonce(), 2);
    }

    // ===== SECURITY TESTS =====

    function test_security_CannotExecuteWithInvalidSignature() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        // Create invalid signatures
        uint8[] memory sigV = new uint8[](2);
        bytes32[] memory sigR = new bytes32[](2);
        bytes32[] memory sigS = new bytes32[](2);

        sigV[0] = 27;
        sigV[1] = 28;
        sigR[0] = bytes32(uint256(1));
        sigR[1] = bytes32(uint256(2));
        sigS[0] = bytes32(uint256(3));
        sigS[1] = bytes32(uint256(4));

        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
    }

    function test_security_CannotExecuteWithDuplicateSignatures() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        // Get same signature twice (duplicate)
        uint256 privateKey = getPrivateKeyForAddress(owners[0]);
        (uint8 v, bytes32 r, bytes32 s) = signTransaction(
            privateKey, recipient, amount, data, 0, address(0), 100000
        );

        uint8[] memory sigV = new uint8[](2);
        bytes32[] memory sigR = new bytes32[](2);
        bytes32[] memory sigS = new bytes32[](2);

        sigV[0] = v;
        sigV[1] = v;
        sigR[0] = r;
        sigR[1] = r;
        sigS[0] = s;
        sigS[1] = s;

        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
    }

    function test_security_CannotReuseSignaturesAcrossTransactions() public {
        address recipient = address(0x9999);
        uint256 amount = 1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        // Get signatures for first transaction
        (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                        getSignedTransaction(privateKeys, recipient, amount, data, 0, address(0), 100000);

        // Execute first transaction
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
        assertEq(multisig.nonce(), 1);

        // Try to reuse same signatures (should fail due to nonce)
        vm.expectRevert();
        multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
    }

    // ===== STRESS TESTS =====

    function test_stress_SequentialTransactions() public {
        uint256 numTransactions = 5;
        address recipient = address(0x9999);
        uint256 amount = 0.1 ether;
        bytes memory data = "";

        uint256[] memory privateKeys = new uint256[](2);
        privateKeys[0] = getPrivateKeyForAddress(owners[0]);
        privateKeys[1] = getPrivateKeyForAddress(owners[1]);

        uint256 initialBalance = recipient.balance;

        for (uint256 i = 0; i < numTransactions; i++) {
            (uint8[] memory sigV, bytes32[] memory sigR, bytes32[] memory sigS) =
                            getSignedTransaction(privateKeys, recipient, amount, data, i, address(0), 100000);

            multisig.execute(sigV, sigR, sigS, recipient, amount, data, address(0), 100000);
            assertEq(multisig.nonce(), i + 1);
        }

        assertEq(recipient.balance, initialBalance + (amount * numTransactions));
    }
}
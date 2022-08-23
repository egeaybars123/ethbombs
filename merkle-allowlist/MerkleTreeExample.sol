//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleTree {
    
    bytes32 public merkleRoot = 0x56acbdfe222fc182d2a520ed8dfd463d8768708021037f3412e91a736448089b;

    function whitelistMint(bytes32[] calldata _merkleProof, address _addr) public view returns(bool){
        bytes32 leaf = keccak256(abi.encodePacked(_addr));
        return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }
}

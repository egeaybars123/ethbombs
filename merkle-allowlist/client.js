//SHOULD BE USED FOR NODE.JS

const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const merkleTree = require("./merkletree.json");

let leaves = [];

for (let leaf in merkleTree.leaves) {
    //console.log(merkleTree.leaves[leaf].data.toString("hex"));
    leaves.push(Buffer.from(merkleTree.leaves[leaf].data));
}

const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const rootHash = tree.getRoot();

function isWhitelisted(addr) {
    const allowed_addr = keccak256(addr);
    const hexProof = tree.getHexProof(allowed_addr);

    //logs the proof needed to provide to the Solidity smart contract!
    console.log(hexProof);
    return tree.verify(hexProof, allowed_addr, rootHash);
}

const result = isWhitelisted("0x803b83eaf89ff3e19aa3d6832d100ef10da8e8d0");
console.log(result);

/* SHOULD BE USED FOR BROWSER

import fetch from "node-fetch";

async function fetchMerkle() {
    let response = await fetch("merkletree.json");
    let data = await response.json();
    console.log(data);
}

*/
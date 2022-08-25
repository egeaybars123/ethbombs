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

//Root of the Merkle tree in Buffer
const rootHash = tree.getRoot();

//Root of the Merkle tree in hex format
console.log(tree.getHexRoot());

function isWhitelisted(addr) {
    const allowed_addr = keccak256(addr);
    const hexProof = tree.getHexProof(allowed_addr);

    //logs the proof needed to provide to the Solidity smart contract!
    //Stringify the object to pass it as a parameter to the mint function
    console.log(JSON.stringify(hexProof));

    return tree.verify(hexProof, allowed_addr, rootHash);
}

const result = isWhitelisted("0xfa1f66bff1F34d8cF6E4132a3BD5712c9b0d8011");
console.log(result);

const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const fs = require("fs");
const addresses = require("./addresses.json");

const allowlist = addresses.addresses;
console.log(allowlist.length);

const leafNodes = allowlist.map(addr => keccak256(addr));
const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });

const data = JSON.stringify(merkleTree);


// write JSON string to a file
fs.writeFile('merkletree.json', data, (err) => {
    if (err) {
        throw err;
    }
    console.log("Addresses are saved as JSON successfully.");
});


const rootHexHash = merkleTree.getHexRoot();
//const rootHash = merkleTree.getRoot();


console.log("Whitelist Merkle Tree: \n", merkleTree.toString());
console.log(rootHexHash);


//Client-side code where address of the user is retrieved and checked with the tree

//To check if an address is in the list, hash it with keccak256 and get the HexProof to
//verify later with the tree object.
/*
const allowed_addr = keccak256("0X6E21D37E07A6F7E53C7ACE372CEC63D4AE4B6BD0");
const hexProof = merkleTree.getHexProof(allowed_addr);

console.log(merkleTree.verify(hexProof, allowed_addr, rootHash));
*/


/*
let allowlist_addresses = [
    "0X5B38DA6A701C568545DCFCB03FCB875F56BEDDC4",
    "0X5A641E5FB72A2FD9137312E7694D42996D689D99",
    "0XDCAB482177A592E424D1C8318A464FC922E8DE40",
    "0X6E21D37E07A6F7E53C7ACE372CEC63D4AE4B6BD0",
    "0X09BAAB19FC77C19898140DADD30C4685C597620B",
    "0XCC4C29997177253376528C05D3DF91CF2D69061A",
    "0xdD870fA1b7C4700F2BD7f44238821C26f7392148" 
  ];
*/


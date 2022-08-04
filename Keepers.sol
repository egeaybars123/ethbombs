//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/*
enum Colors {
        PACKAGE,
        BLUE,
        GREEN,
        ORANGE,
        PINK,
        PURPLE,
        RED,
        YELLOW
    }
*/
contract Keepers is ERC721, ERC721URIStorage, VRFConsumerBaseV2 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    //address public owner;

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    bytes32 internal keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint16 requestConfirmations = 3;
    //uint256[] public s_randomWords;
    //uint256 public s_requestId;
    uint32 callbackGasLimit = 100000;
    uint32 numWords = 1;

    mapping (uint256 => uint256) requestToTokenID;
    mapping (uint256 => uint256) tokenIDtoColor;

    //mapping (uint => bool) public bigPrize; //7 Ether
    //mapping (uint => bool) public mediumPrize; //0.1 Ether

    //For Rinkeby Test Network:
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    //address LinkToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;

    uint256[7] referenceArray = [
        1, //Blue
        2, //Green
        3, //Orange
        4, //Pink
        5, //Purple
        6, //Red
        7 //Yellow
    ];

    string[7] bombIPFS = [
        "blue.ipfs",
        "green.ipfs",
        "orange.ipfs",
        "pink.ipfs",
        "purple.ipfs",
        "red.ipfs",
        "yellow.ipfs"
    ];

    //subscriptionID: 9753 
    constructor(uint64 _subscriptionId) VRFConsumerBaseV2(vrfCoordinator) ERC721("My NFT", "MNFT"){
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = _subscriptionId;
    }

    function safeMint(address to) public payable {
        require(msg.value == 1000000000000000, "Not enough ETH sent"); //Mint price is 0.001 Ether
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        requestRandomWords(tokenId);
    }

    function getContractBalance() view public returns(uint){
        return address(this).balance;
    }

    // Assumes the subscription is funded sufficiently.
    // Will revert if subscription is not set and funded.

    // Brings random number to change the metadata of the NFT.
    // Assigns colors to the NFTs randomly.
    
    function requestRandomWords(uint256 tokenID) internal {
        //require(tokenIDtoColor[tokenID] == 1); 
        uint256 s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
        
        requestToTokenID[s_requestId] = tokenID; //check if only owner can change.
    }

    function fulfillRandomWords(
        uint256 requestID,
        uint256[] memory randomWords
    ) internal override {
        uint256 randomValue = (randomWords[0] % 7) + 1;
        _setTokenURI(requestToTokenID[requestID], bombIPFS[randomValue]);
    }

    // The following functions (burn and tokenURI) are overrides required by Solidity.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}

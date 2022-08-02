//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Keepers is ERC721, ERC721URIStorage, VRFConsumerBaseV2 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    address public owner;

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    bytes32 keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint16 requestConfirmations = 3;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    uint32 callbackGasLimit = 150000;
    uint32 numWords = 1;

    mapping (uint => bool) public bigPrize; //7 Ether
    mapping (uint => bool) public mediumPrize; //0.1 Ether

    //For Rinkeby Test Network:
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    address LinkToken = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;

    string defaultIPFS = "package";

    string[] public bombIPFS = [
        "blue",
        "green",
        "orange",
        "pink",
        "purple",
        "red",
        "yellow"
    ];

    //subscriptionID for Rinkeby: 9753 
    constructor(uint64 _subscriptionId) VRFConsumerBaseV2(vrfCoordinator) ERC721("My NFT", "MNFT"){
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        owner = msg.sender;
        subscriptionId = _subscriptionId;
    }

    function safeMint(address to) internal {
        //require(msg.value == 0.001 ether); //Mint price is 1 Ether
        uint256 randomValue = (s_randomWords[0] % 7) + 1;
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, bombIPFS[randomValue]);
    }

    function getContractBalance() view public returns(uint){
        return address(this).balance;
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords() external {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;

    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
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

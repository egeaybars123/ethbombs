//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract Keepers is ERC721, ERC721URIStorage, VRFConsumerBaseV2 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    bytes32 internal keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint16 requestConfirmations = 3;
    //uint256[] public s_randomWords;
    //uint256 public s_requestId;
    uint32 callbackGasLimit = 120000;
    uint32 numWords = 1;

    /*
        Counting how many days passed till the start.
        This will be important to limit how many NFTs could
        be minted in a day.
    */
    uint256 dayIndex = 1;
    uint256 dailyLeft = 1; //Number of NFTs left for the day. //1111
    uint256 lastRandomforExplode;
    bool readyForExplode = false;

    mapping (uint256 => uint256) requestToTokenID;
    mapping (uint256 => uint256) tokenIDtoColorID;

    //mapping (uint => bool) public bigPrize; //7 Ether
    //mapping (uint => bool) public mediumPrize; //0.1 Ether

    //For Rinkeby Test Network:
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

    //Array of the remaining colors which did not explode
    uint256[] public dynamicArray = [
        3, //Blue //7000
        6, //Green //14000
        9, //Orange //21000
        12, //Pink //28000
        15, //Purple //35000
        18, //Red //42000
        21 //Yellow //49000
    ];
    
    //Array of the remaining tokenURIs
    string[] public bombIPFSDynamic = [
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
        require(dailyLeft > 0, "Maximum number reached for the day"); //Max number of NFTs that could be minted in a day
        require(dayIndex <= 7, "Event over"); //After day 7, NFTs cannot be minted.
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        requestRandomWords(tokenId);
    }

    // Assumes the subscription is funded sufficiently.
    // Will revert if subscription is not set and funded.

    // Brings random number to change the metadata of the NFT.
    // Assigns colors to the NFTs randomly.
    
    function requestRandomWords(uint256 tokenID) internal {
        uint256 s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
        
        requestToTokenID[s_requestId] = tokenID;
        dailyLeft--;
    }

    function fulfillRandomWords(
        uint256 requestID,
        uint256[] memory randomWords
    ) internal override {

        if (!readyForExplode) {
            uint256 randomValue = (randomWords[0] % dynamicArray.length) + 1;
            uint256 colorID = dynamicArray[randomValue];
            uint256 tokenID = requestToTokenID[requestID];
            _setTokenURI(tokenID, bombIPFSDynamic[(colorID / 3) - 1]); //Divide by 7000
            tokenIDtoColorID[tokenID] = colorID;
            dynamicArray[randomValue] += 1;
        }
        else {
            uint256 randomValue = (randomWords[0] % dynamicArray.length) + 1;
            removeColor(randomValue);
        }
        
    }

    /*
        Triggered by Chainlink Keepers every day to reset
        the maximum amount of NFTs that can be minted and 
        increment the number of days.
    */
    function keepersTrigger() internal {
        dayIndex++;
        dailyLeft = 1; //1111
        readyForExplode = true;
        
        //Request random words for explosion.
        COORDINATOR.requestRandomWords(
        keyHash,
        subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
    }

    function removeColor(uint256 index) internal {
        dynamicArray[index] = dynamicArray[dynamicArray.length - 1];
        dynamicArray.pop();
    }

    function getContractBalance() view public returns(uint){
        return address(this).balance;
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

//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract BombsNFT is ERC721, ERC721URIStorage, VRFConsumerBaseV2, KeeperCompatible {
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIdCounter;

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    bytes32 internal keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint16 requestConfirmations = 3;
    uint256[1] public randomWordsForRewards;
    //uint256 public s_requestId;
    uint32 callbackGasLimit = 120000;
    uint32 numWords = 1;

    /*
        Counting how many days passed till the start.
        This will be important to limit how many NFTs could
        be minted in a day.
    */
    uint256 lastTimestamp;
    bool readyForTeamWithdrawal;

    mapping (uint256 => uint256) public tokenIDtoColorID;
    mapping (uint256 => bool) public bigPrize; //1 Ether
    mapping (uint256 => bool) public mediumPrize; //0.1 Ether

    //For Rinkeby Test Network:
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

    //Array of the colorIDs
    uint256[] public dynamicArray = [
        3, //Blue //1111
        6, //Green //2222
        9, //Orange //3333
        12, //Pink //4444
        15, //Purple //5555
        18, //Red //6666
        21 //Yellow //7777
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

    function safeMint(address to, uint256 index) public payable {
        require(0 <= index && index <= 6, "No such color found");
        require((dynamicArray[index] / 3) == index + 1, "Color sold out"); // 1111
        require(msg.value == 1000000000000000, "Not enough ETH"); //Mint price is 0.001 Ether
        uint256 tokenId = _tokenIdCounter.current();
        tokenIDtoColorID[tokenId] = dynamicArray[index];
        dynamicArray[index] += 1;
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, bombIPFSDynamic[index]);

    }

    // Assumes the subscription is funded sufficiently.
    // Will revert if subscription is not set and funded.
    
    function requestRandomWords() internal {
        COORDINATOR.requestRandomWords(
        keyHash,
        subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );  
    }

    function fulfillRandomWords(
        uint256, /* requestID */
        uint256[] memory randomWords
    ) internal override {
        
        uint256 randomValue = (randomWords[0] % dynamicArray.length) + 1;
        removeColor(randomValue);
        randomWordsForRewards[0] = randomWords[0];
         
    }

    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        
        if(keccak256(checkData) == keccak256(hex'01')) {
            //check if all NFT is sold out and 24-hour passed for color explosions
            upkeepNeeded = (_tokenIdCounter.current() > 7775) && ((block.timestamp - lastTimestamp) > 86400);
            performData = checkData; 
        }

        if(keccak256(checkData) == keccak256(hex'02')) {
            upkeepNeeded = (dynamicArray.length == 1);
            performData = checkData;
        }

        /*
        if(keccak256(checkData) == keccak256(hex'03')) {
            //check if random number for reward lottery has arrived from VRF
            upkeepNeeded = randomWordsForRewards[0] != 0; 
            performData = checkData;
        }
        */
            
    }
    
    function performUpkeep(bytes calldata performData) external override{
        if(keccak256(performData) == keccak256(hex'01') && 
            _tokenIdCounter.current() > 7775 && 
            (block.timestamp - lastTimestamp) > 86400) {

            lastTimestamp = block.timestamp;
            requestRandomWords();
        }

        if(keccak256(performData) == keccak256(hex'02')) {
            //add the function for rewards distributions
            readyForTeamWithdrawal = true;
        }
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

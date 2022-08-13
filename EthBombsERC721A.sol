//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "erc721a/contracts/ERC721A.sol";

contract BombsNFT is ERC721A, ReentrancyGuard, Ownable, VRFConsumerBaseV2, KeeperCompatible {

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    bytes32 internal keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint16 requestConfirmations = 3;
    uint256[1] public randomWordsForRewards;
    //uint256 public s_requestId;
    uint32 callbackGasLimit = 120000;
    uint32 numWords = 1;

    uint256 lastTimestamp;
    bool readyForTeamWithdrawal;

    struct WinnerInfo {
        bool eligible; 
        bool withdrawn; //set to true when winner ID withdraws the prize
    }

    mapping (uint256 => string) public tokenIDtoURIs;
    mapping (uint256 => uint256) public tokenIDtoColorID;
    mapping (uint256 => WinnerInfo) public checkBigPrize; //1 Ether
    mapping (uint256 => WinnerInfo) public checkSmallPrize; //0.1 Ether

    //For Rinkeby Test Network:
    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;

    //Array of the colorIDs
    uint256[] public dynamicArray = [
        1111, //Blue 
        2222, //Green 
        3333, //Orange 
        4444, //Pink 
        5555, //Purple 
        6666, //Red 
        7777 //Yellow 
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
    constructor(uint64 _subscriptionId) VRFConsumerBaseV2(vrfCoordinator) ERC721A("My NFT", "MNFT") {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = _subscriptionId;
    }

    function mint(uint256[] memory colorList) external payable {
        uint256 quantity = colorList.length;
        require(msg.value == 7000000000000000 * quantity, "Not enough ETH"); //Mint price is 0.007 Ether
        require(quantity + _numberMinted(msg.sender) <= 11, "Max amount of NFTs claimed for this address"); //Max mint per address set to 11

        uint256 totalMinted = _totalMinted();

        for (uint i; i < quantity; i++) {
            uint256 index = colorList[i];
            assert((dynamicArray[index] / 1111) == index + 1); // checks if the color is sold out.
            tokenIDtoColorID[totalMinted] = dynamicArray[index];
            tokenIDtoURIs[totalMinted] = bombIPFSDynamic[index];
            dynamicArray[index] += 1;
            totalMinted++;
        }
        //try adding tokenURI by overriding tokenURI function and checking which colorID corresponds
        //to the tokenID and add to that baseURI.
        _safeMint(msg.sender, quantity);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "ipfs://BpofOIFOoibOIBOIFBRGO043209842IBFWBU/";
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        uint256 colorID = tokenIDtoColorID[tokenId];
        uint256 colorIPFS = colorID / 3;
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(colorIPFS))) : '';
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
        uint256 explodedColorIndex = (randomWords[0] % dynamicArray.length) + 1;
        removeColor(explodedColorIndex);
        randomWordsForRewards[0] = randomWords[0];
    }

    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        if(keccak256(checkData) == keccak256(hex'01')) {
            //check if all NFT is sold out and 24-hour passed for color explosions
            upkeepNeeded = (_totalMinted() > 7775) && ((block.timestamp - lastTimestamp) > 86400);
            performData = checkData; 
        }

        if(keccak256(checkData) == keccak256(hex'02')) {
            upkeepNeeded = (dynamicArray.length == 1);
            performData = checkData;
        }           
    }
    
    function performUpkeep(bytes calldata performData) external override{
        if(keccak256(performData) == keccak256(hex'01') && 
            _totalMinted() > 7776 && 
            (block.timestamp - lastTimestamp) > 86400) {

            lastTimestamp = block.timestamp;
            requestRandomWords();
        }

        if(keccak256(performData) == keccak256(hex'02') && 
            (dynamicArray.length == 1)) {
            //set 2.2 million gas for determineWinners function
            readyForTeamWithdrawal = true;
            determineWinners(randomWordsForRewards[0]);
        }
    }

    function determineWinners(uint256 randomNumber) internal {

        //determine 1 ETH winners - 7 IDs
        for (uint i; i < 7; i++) {
            uint256 colorID = randomNumber % 1111;
            while(checkBigPrize[colorID].eligible) {
                randomNumber >>= 1;
                colorID = randomNumber % 1111;
            }
            checkBigPrize[colorID].eligible = true;
            randomNumber >>= 1;
        }

        //determine 0.1 ETH winners - 70 IDs
        for (uint i; i < 70; i++) {
            uint256 colorID = randomNumber % 1111;
            while(checkBigPrize[colorID].eligible || checkSmallPrize[colorID].eligible) {
                randomNumber >>= 1;
                colorID = randomNumber % 1111;
            }
            checkSmallPrize[colorID].eligible = true;
            randomNumber >>= 1;
        }
    }

    function withdrawBigPrize(uint256 tokenID) public payable nonReentrant {
        require(ownerOf(tokenID) == msg.sender);

        uint256 colorID = tokenIDtoColorID[tokenID];
        uint256 baseID = dynamicArray[0] - 1110;
        uint256 checkID = colorID - baseID; //check if 0 works - it works!
        require(checkBigPrize[checkID].eligible && !checkBigPrize[checkID].withdrawn, 
        "ID is not eligible for reward or ID has withdrawn the prize");
        
        checkBigPrize[checkID].withdrawn = true;
        (bool sent, ) = msg.sender.call{value: 1 ether}("");
        require(sent, "Failed to send the rewards");
    }

    function withdrawSmallPrize(uint256 tokenID) public payable nonReentrant {
        require(ownerOf(tokenID) == msg.sender);

        uint256 colorID = tokenIDtoColorID[tokenID];
        uint256 baseID = dynamicArray[0] - 1110;
        uint256 checkID = colorID - baseID; //check if 0 works - it works!
        require(checkSmallPrize[checkID].eligible && !checkSmallPrize[checkID].withdrawn, 
        "ID is not eligible for reward or ID has withdrawn the prize");
        //add setting withdrawn to true and transferring the ether later
        checkSmallPrize[checkID].withdrawn = true;
        (bool sent, ) = msg.sender.call{value: 0.1 ether}("");
        require(sent, "Failed to send the rewards");
    }

    function withdrawTeam() public payable nonReentrant onlyOwner {
        require(readyForTeamWithdrawal, "Winners not determined yet");
        readyForTeamWithdrawal = false;
        (bool sent,) = msg.sender.call{value: 5.4439 ether}("");
        require(sent, "Failed to send Ether");
    }

    function removeColor(uint256 index) internal {
        dynamicArray[index] = dynamicArray[dynamicArray.length - 1];
        dynamicArray.pop();
    }

    function getContractBalance() view public returns(uint){
        return address(this).balance;
    }
}

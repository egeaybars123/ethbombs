//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

//Mainnet contract
contract EthBombsNFT is ERC721A, ERC721AQueryable, ReentrancyGuard, Ownable, VRFConsumerBaseV2, KeeperCompatible {

    VRFCoordinatorV2Interface COORDINATOR;
    
    //SubscriptionID for the VRF. Make sure that this contract address is added as a consumer
    //to the subscriptionID.
    uint64 subscriptionId;

    //200 gwei gas lane for VRF
    bytes32 private keyHash = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;

    //50 blocks need to be confirmed in the Ethereum for the random number to be confirmed. 
    uint16 private requestConfirmations = 50; //?

    //120000 gas for fullfillRandomWords() function
    uint32 private callbackGasLimit = 120000;

    //One random number is returned every day
    uint32 numWords = 1;

    //VRF random numbers are stored here.
    uint256[1] public randomWordsForRewards;

    uint256 lastTimestamp;

    bool readyForTeamWithdrawal;
    bool readyForBigBangRewards;
    bool winnersDetermined;

    struct WinnerInfo {
        bool eligible; 
        bool withdrawn; //set to true when winner ID withdraws the prize
    }

    mapping (uint256 => uint256) public tokenIDtoColorID;
    mapping (uint256 => WinnerInfo) public checkBigPrize; //1 Ether
    mapping (uint256 => WinnerInfo) public checkSmallPrize; //0.01 Ether

    //For Ethereum Mainnet
    address vrfCoordinator = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;

    //Array of the colorIDs
    //Max number of color that can be minted is 1111.
    //For example, between 1111-2221, colorIDs will be minted for blue. 
    uint256[] public dynamicArray = [
        1111, //Blue 
        2222, //Green 
        3333, //Orange 
        4444, //Pink 
        5555, //Purple 
        6666, //Red 
        7777 //Yellow 
    ];

    //Enter a subscription ID for VRF before deploying the contract! 
    constructor(uint64 _subscriptionId) VRFConsumerBaseV2(vrfCoordinator) ERC721A("ETH BOMBS", "EBOMB") {
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
            require((dynamicArray[index] / 1111) == index + 1); // checks if the color is sold out.
            tokenIDtoColorID[totalMinted] = dynamicArray[index];
            dynamicArray[index] += 1;
            totalMinted++;
        }
        _safeMint(msg.sender, quantity);
    }

    //IPFS link for the metadata
    function _baseURI() internal view virtual override returns (string memory) {
        return "ipfs://bafybeih7a6psjgkekbvkrnkk7zcq4mol6dd4p7w7zmxa7rk4bclt2zwl4u/";
    }

    //tokenURI is given according to the colorID. For example, color ID is 2243, divide it by 
    //1111 and the result is 2, so green color is set as URI for a given tokenID.
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        uint256 colorID = tokenIDtoColorID[tokenId];
        uint256 colorIPFS = colorID / 1111;
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

    //Chainlink nodes execute this function when the random number is available.
    function fulfillRandomWords(
        uint256, /* requestID */
        uint256[] memory randomWords
    ) internal override {

        //This if block is used to explode the colors.
        if (dynamicArray.length > 1) {
            uint256 explodedColorIndex = randomWords[0] % dynamicArray.length; 
            removeColor(explodedColorIndex);
            randomWordsForRewards[0] = randomWords[0];
        }
        
        //winnersDetermined is set to true for the second Upkeep to work.
        if(dynamicArray.length == 1) {
            winnersDetermined = true;
        }
    }

    //Checked every block by the Chainlink nodes off-chain.
    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        //First upkeep job to explode the colors every day. 
        if(keccak256(checkData) == keccak256(hex'01')) {
            upkeepNeeded = (_totalMinted() > 7776) && ((block.timestamp - lastTimestamp) > 86400) && (dynamicArray.length != 1);
            performData = checkData; 
        }

        //Second upkeep job to determine the winners.
        if(keccak256(checkData) == keccak256(hex'02')) {
            upkeepNeeded = (dynamicArray.length == 1) && winnersDetermined;
            performData = checkData;
        }           
    }
    
    //In this function, upkeeps are executed on-chain. These jobs are called
    //by Chainlink nodes.
    function performUpkeep(bytes calldata performData) external override{
        if(keccak256(performData) == keccak256(hex'01') && 
            (_totalMinted() > 7776) && (dynamicArray.length != 1) &&
            (block.timestamp - lastTimestamp) > 86400) {

            lastTimestamp = block.timestamp;
            requestRandomWords();
        }

        if(keccak256(performData) == keccak256(hex'02') && 
            (dynamicArray.length == 1) &&
            winnersDetermined) {
            //set 2.5 million gas for determineWinners function
            readyForTeamWithdrawal = true;
            readyForBigBangRewards = true;
            winnersDetermined = false;
            determineWinners(randomWordsForRewards[0]);
        }
    }

    //Determines the winners- first 7 are 1 ETH winners, and the other
    //70 are 0.1 ETH winners.
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

    //
    function withdrawBigPrize(uint256 tokenID) public payable nonReentrant {
        require(ownerOf(tokenID) == msg.sender);

        uint256 colorID = tokenIDtoColorID[tokenID];
        uint256 baseID = dynamicArray[0] - 1111;
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
        uint256 baseID = dynamicArray[0] - 1111;
        uint256 checkID = colorID - baseID; 
        require(checkSmallPrize[checkID].eligible && !checkSmallPrize[checkID].withdrawn, 
        "ID is not eligible for reward or ID has withdrawn the prize");
        
        checkSmallPrize[checkID].withdrawn = true;
        (bool sent, ) = msg.sender.call{value: 0.01 ether}("");
        require(sent, "Failed to send the rewards");
    }

    function withdrawTeam() public payable nonReentrant onlyOwner {
        require(readyForTeamWithdrawal, "Winners not determined yet");
        readyForTeamWithdrawal = false;
        (bool sent,) = msg.sender.call{value: 5.4 ether}(""); //??????
        require(sent, "Failed to send Ether");
    }

    function withdrawBigBangRewards() public payable nonReentrant onlyOwner {
        require(readyForBigBangRewards, "Winners not determined yet");
        readyForBigBangRewards = false;
        (bool sent,) = address(0xc3a3877197223e222F90E3248dEE2360cAB56D6C).call{value: 0.01 ether}(""); //???
        require(sent, "Failed to send Ether");
    }

    //checks if the remaining color holder is eligible for airdrop for BIGBANG. 
    //The color holder should not be the winner for big or small prize.
    function eligibleForAirdrop(uint256 tokenID) public view returns (bool) {
        uint256 colorID = tokenIDtoColorID[tokenID];
        uint256 baseID = dynamicArray[0] - 1111;
        uint256 checkID = colorID - baseID;

        if(!checkBigPrize[checkID].eligible && !checkSmallPrize[checkID].eligible && 
        colorID  >= baseID && colorID < dynamicArray[0]) {
            return true;
        }
        return false;
    }

    //Removes the color ID from the array.
    function removeColor(uint256 index) internal {
        dynamicArray[index] = dynamicArray[dynamicArray.length - 1];
        dynamicArray.pop();
    }

    function getContractBalance() view public returns(uint){
        return address(this).balance;
    }

    function showRemainingColors() public view returns(uint256[] memory) {
        return dynamicArray;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

//Goerli testnet contract
contract BombsNFT is ERC721A, ERC721AQueryable, ReentrancyGuard, Ownable, VRFConsumerBaseV2, KeeperCompatible {

    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    
    bytes32 private keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint16 private requestConfirmations = 3;
    uint256[1] private randomWordsForRewards;
    uint32 private callbackGasLimit = 120000;
    uint32 private numWords = 1;

    uint256 lastTimestamp;
    bool readyForTeamWithdrawal;
    bool readyForBigBangRewards;
    bool winnersDetermined;

    struct WinnerInfo {
        bool eligible; 
        bool withdrawn; //set to true when winner ID withdraws the prize
    }

    mapping (uint256 => uint256) public tokenIDtoColorID;
    mapping (uint256 => bool) public explodedColorsMetadata;

    mapping (uint256 => WinnerInfo) public checkBigPrize; //0.01 Ether
    mapping (uint256 => WinnerInfo) public checkSmallPrize; //0.005 Ether

    //For Goerli Test Network:
    address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;

    //Array of the colorIDs
    uint256[] public dynamicArray = [
        5, //Blue 
        10, //Green 
        15, //Orange 
        20, //Pink 
        25, //Purple 
        30, //Red 
        35 //Yellow 
    ];

    event BombMinted(address indexed minter, uint256 indexed colorID, uint256 tokenID);

    //subscriptionID: 71 
    constructor(uint64 _subscriptionId) VRFConsumerBaseV2(vrfCoordinator) ERC721A("ETH BOMBS", "BOOM") {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = _subscriptionId;
    }

    function mint(uint256[] memory colorList) external payable {
        uint256 quantity = colorList.length;
        require(msg.value == 1000000000000000 * quantity, "Not enough ETH"); //Mint price is 0.001 Ether
        require(quantity + _numberMinted(msg.sender) <= 22, "Max amount of NFTs claimed for this address"); //Max mint per address set to 11 in the mainnet contract

        uint256 totalMinted = _totalMinted();

        for (uint i; i < quantity; i++) {
            uint256 index = colorList[i];
            require((dynamicArray[index] / 5) == index + 1); // checks if the color is sold out.
            tokenIDtoColorID[totalMinted] = dynamicArray[index];
            dynamicArray[index] += 1;
            emit BombMinted(msg.sender, index, totalMinted);
            totalMinted++;
        }
        
        _safeMint(msg.sender, quantity);
    }

    function _baseURI() internal view virtual override returns (string memory) {
       return "ipfs://bafybeiajcu2vshmajx2cf7sgmr5uqwyeqqkbp2pq6i2f3vqjkjbpiqtlye/";
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        uint256 colorID = tokenIDtoColorID[tokenId];
        uint256 colorIPFS = colorID / 5;

        if (explodedColorsMetadata[colorIPFS]) {
            return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(8))) : '';
        }

        else {
            return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(colorIPFS))) : '';
        }
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
        if (dynamicArray.length > 1) {
            uint256 explodedColorIndex = randomWords[0] % dynamicArray.length;
            removeColor(explodedColorIndex);
            randomWordsForRewards[0] = randomWords[0];
        }
        
        if(dynamicArray.length == 1) {
            winnersDetermined = true;
        }
    }

    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        if(keccak256(checkData) == keccak256(hex'01')) {
            upkeepNeeded = (_totalMinted() > 34) && ((block.timestamp - lastTimestamp) > 120) && (dynamicArray.length != 1);
            performData = checkData; 
        }

        if(keccak256(checkData) == keccak256(hex'02')) {
            upkeepNeeded = (dynamicArray.length == 1) && winnersDetermined;
            performData = checkData;
        }           
    }
    
    function performUpkeep(bytes calldata performData) external override{
        if(keccak256(performData) == keccak256(hex'01') && 
            (_totalMinted() > 34) && (dynamicArray.length != 1) &&
            (block.timestamp - lastTimestamp) > 120) {

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

    function determineWinners(uint256 randomNumber) internal {

        //determine 1 ETH winners - 7 IDs
        for (uint i; i < 1; i++) {
            uint256 colorID = randomNumber % 5;
            while(checkBigPrize[colorID].eligible) {
                randomNumber >>= 1;
                colorID = randomNumber % 5;
            }
            checkBigPrize[colorID].eligible = true;
            randomNumber >>= 1;
        }

        //determine 0.1 ETH winners - 70 IDs
        for (uint i; i < 2; i++) {
            uint256 colorID = randomNumber % 5;
            while(checkBigPrize[colorID].eligible || checkSmallPrize[colorID].eligible) {
                randomNumber >>= 1;
                colorID = randomNumber % 5;
            }
            checkSmallPrize[colorID].eligible = true;
            randomNumber >>= 1;
        }
    }

    function withdrawBigPrize(uint256 tokenID) public payable nonReentrant {
        require(ownerOf(tokenID) == msg.sender);

        uint256 colorID = tokenIDtoColorID[tokenID];
        uint256 baseID = dynamicArray[0] - 5;
        uint256 checkID = colorID - baseID; //check if 0 works - it works!
        require(checkBigPrize[checkID].eligible && !checkBigPrize[checkID].withdrawn, 
        "ID is not eligible for reward or ID has withdrawn the prize");
        
        checkBigPrize[checkID].withdrawn = true;
        (bool sent, ) = msg.sender.call{value: 0.01 ether}("");
        require(sent, "Failed to send the rewards");
    }

    function withdrawSmallPrize(uint256 tokenID) public payable nonReentrant {
        require(ownerOf(tokenID) == msg.sender);

        uint256 colorID = tokenIDtoColorID[tokenID];
        uint256 baseID = dynamicArray[0] - 5;
        uint256 checkID = colorID - baseID; //Solidity 0.8 throws an error for underflow/overflow
        require(checkSmallPrize[checkID].eligible && !checkSmallPrize[checkID].withdrawn, 
        "ID is not eligible for reward or ID has withdrawn the prize");
        checkSmallPrize[checkID].withdrawn = true;
        (bool sent, ) = msg.sender.call{value: 0.002 ether}("");
        require(sent, "Failed to send the rewards");
    }

    function withdrawTeam() public payable nonReentrant onlyOwner {
        require(readyForTeamWithdrawal, "Winners not determined yet");
        readyForTeamWithdrawal = false;
        (bool sent,) = msg.sender.call{value: 0.01 ether}("");
        require(sent, "Failed to send Ether");
    }

    function withdrawBigBangRewards() public payable nonReentrant onlyOwner {
        require(readyForBigBangRewards, "Winners not determined yet");
        readyForBigBangRewards = false;
        (bool sent,) = address(0xc3a3877197223e222F90E3248dEE2360cAB56D6C).call{value: 0.01 ether}("");
        require(sent, "Failed to send Ether");
    }

    function eligibleForAirdrop(uint256 tokenID) public view returns (bool) {
        uint256 colorID = tokenIDtoColorID[tokenID];
        uint256 baseID = dynamicArray[0] - 5;
        uint256 checkID = colorID - baseID;

        if(!checkBigPrize[checkID].eligible && !checkSmallPrize[checkID].eligible && 
        colorID  >= baseID && colorID < dynamicArray[0]) {
            return true;
        }
        return false;
    }

    function removeColor(uint256 index) internal {
        explodedColorsMetadata[index + 1] = true;
        dynamicArray[index] = dynamicArray[dynamicArray.length - 1];
        dynamicArray.pop();
    }

    function getContractBalance() public view returns(uint256){
        return address(this).balance;
    }

    function showRemainingColors() public view returns(uint256[] memory) {
        return dynamicArray;
    }

    function showNumberMinted(address minter) external view returns (uint256) {
        return _numberMinted(minter);
    }
}

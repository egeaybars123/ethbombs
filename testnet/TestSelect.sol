//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

contract Test {

    uint256[] public bigPrize;
    uint256[] public smallPrize;

    //15237046774827599886663330186809822076396545411607807066012959162276402429988
    function distribute(uint256 randomNumber, uint256 colorID) pure public returns (bool){
        for (uint i; i < 70; i++) {
            if (randomNumber % 1111 == colorID) {
                return true;
            }
            randomNumber >>= 1;
        }
        return false;
    }

    /*
    //Selecting a winner based on tokenID.
    function select(uint256 number1, uint256 number2, uint256 randomness) pure public returns(uint256) {
        uint256 tokenID = number1 % number2;
        uint256 result = (randomness % tokenID) + 1;
        uint256 last = number1 - tokenID + result;
        return last;
    }
    function divide(uint256 number1, uint256 number2) pure public returns(uint256) {
        return number1 / number2;
    }
    */
}

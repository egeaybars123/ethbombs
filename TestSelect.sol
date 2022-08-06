//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

contract Test {

    //Selecting a winner based on tokenID.
    function select(uint256 number1, uint256 number2, uint256 randomness) pure public returns(uint) {
        uint256 tokenID = number1 % number2;
        uint256 result = (randomness % tokenID) + 1;
        uint256 last = number1 - tokenID + result;
        return last;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol"; 

contract Accountant is Ownable { 
    //                 0         1         2
    enum incomeName {salary, investings, other}
    int public currentBalance; 

    struct Catigory {
        string name;
        int catigorySpendings; 
    }

    string[] catigorieName; 
 
    mapping (incomeName => int) public incomes;
    //Catigories names: health, food, clothes 
    mapping (string => Catigory) public catigories;

    function viewCatigories() external view returns(string[] memory){
        return catigorieName; 
    } 
    
    function addCategory(string calldata _name) external onlyOwner {
        Catigory storage catigory = catigories[_name];
        catigory.name = _name; 
        catigorieName.push(_name);
    }
    //_incomeName: 0 = salary, 1 = investings, 2 = other
    function addIncome(int _amount, incomeName _incomeName) external {
        require(_amount > 0, "income can not be 0 or less");
        incomes[_incomeName] += _amount;
        currentBalance += _amount;  
    }

    function addSpending(
        int _amount, 
        string calldata _catigoryName
        ) contains(_catigoryName, catigories[_catigoryName].name) external { 
        require(_amount > 0, "amount can not be 0 or less"); 
        catigories[_catigoryName].catigorySpendings -= _amount; 
        currentBalance -= _amount;  
    } 
    //checks if catigorie name exists
    modifier contains (string memory what, string memory where) {
    bytes memory whatBytes = bytes (what);
    bytes memory whereBytes = bytes (where);

    require(whereBytes.length >= whatBytes.length, "incorrect catigory name");

    bool found = false;
    for (uint i = 0; i <= whereBytes.length - whatBytes.length; i++) {
        bool flag = true;
        for (uint j = 0; j < whatBytes.length; j++)
            if (whereBytes [i + j] != whatBytes [j]) {
                flag = false;
                break;
            }
        if (flag) {
            found = true;
            break;
        }
    }
    require (found);
    _;
    }
}

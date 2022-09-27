// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol"; 

contract Accountant is Ownable { 
    //                 0         1         2
    enum incomeName {salary, investings, other} 

    struct Catigory {
        string name;
        mapping (address => int) catigorySpendings; 
    }

    string[] catigorieNames; 
    
    mapping(address => mapping (incomeName => int)) incomes; 
    mapping (string => Catigory) catigories;//Catigories names for example: health, food, clothes
    mapping(address => int) balances;
    //to look how many user spend for some category
    function viewCategorySpendings(string calldata _catigoryName) external view returns(int) {
        return catigories[_catigoryName].catigorySpendings[msg.sender]; 
    } 
    //to look msg.sender balance(incomes - spendings)
    function viewBalance() external view returns(int) {
        return balances[msg.sender]; 
    }
    //to look entire balance of salary/investings/other income 
    function viewIncome(incomeName _incomeName) external view returns(int) {
        return incomes[msg.sender][_incomeName]; 
    }
    //to look all existing categories 
    function viewCatigories() external view returns(string[] memory){
        return catigorieNames; 
    } 
    
    function addCategory(string calldata _name) external onlyOwner {
        Catigory storage catigory = catigories[_name];
        catigory.name = _name; 
        catigorieNames.push(_name);
    }
    //_incomeName: 0 = salary, 1 = investings, 2 = other
    function addIncome(int _amount, incomeName _incomeName) external {
        require(_amount > 0, "income can not be 0 or less");
        incomes[msg.sender][_incomeName] += _amount;
        balances[msg.sender] += _amount;   
    }

    function addSpending(
        int _amount, 
        string calldata _catigoryName
        ) contains(_catigoryName, catigories[_catigoryName].name) external { 
        require(_amount > 0, "amount can not be 0 or less"); 
        catigories[_catigoryName].catigorySpendings[msg.sender] -= _amount;
        balances[msg.sender] -= _amount;   
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

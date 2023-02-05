// SPDX-License-Identifier: GPL-3.0 

pragma solidity >=0.5.0 <0.9.0;

//This is code to a fully-ERC20-compliant function which has 6 functions and 2 events
interface ERC20Interface{
    //Not all 6 functions are mandotary but the first 3 functions are mandotoary
    function totalSupply() external view returns(uint);
    function balanceOf(address tokenOwner) external view returns(uint balance);
    function transfer(address to,uint tokens) external returns (bool success);

    function allowance(address tokenOwner,address spender) external view returns (uint remaining);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract Cryptos is ERC20Interface{
    //The Cryptos contract must implement all the functions of the ERC20 standard
    string public name = "Cryptos";
    string public symbol = "CRPT";
    uint public decimals = 0;//18 is the most used value for decimal state variable
    //It represents the totalSupply represents the total number of tokens, Note that it is already in the interface so we must override it 
    //The override keyword is necessary as it creates a getter function ,we must use the exact names as mentioned in the interface
    uint public override totalSupply;

    //The founder is the address that deploys the contract and has all the token at the starting
    address public founder;
    //Now we create mapping to keep a track of all the tokens
    mapping(address => uint) public balances;

    //Here we define new state variable of type allowed
    mapping(address => mapping(address => uint)) allowed;
    /* Here is how it will work
    Lets say 0x111 is the owner 
    and 0x222 is the spender which has been given 100 tokens to spend
    allowed[0x111][0x222] = 100;
    */

    //Now let us declare the mandotary functions we have just the first 3 mandotary functions
    constructor(){
        totalSupply = 100000;
        founder = msg.sender;
        balances[founder] = totalSupply;//Intially the founder will have all the funds
    }

    //Let us add the balanceOf function now
    function balanceOf(address tokenOwner) public view override returns(uint balance){
        return balances[tokenOwner];
    }

    //For any other address to get the tokens we need the transfer function
    function transfer(address to,uint tokens) public virtual override returns (bool success){
        require(balances[msg.sender] >= tokens);

        //The address which will receive the tokens incrementing their tokens
        balances[to] += tokens;

        //As the tokens are sent now we need to decerement the number of tokens from the sender 
        balances[msg.sender] -= tokens;

        //Now that the tokens have been updated the function should emit a event this is a log message that is safe on the blockchain
        emit Transfer(msg.sender,to,tokens);
        //if function reaches this point
        return true;
    }

    /* 
    The transfer function is used to send tokens from one user to the other but it dosent work well when tokens are being used to pay for a
    function in a smart contract 

    ERC20 standard defines a mapping data structure named allowed and 2 functions approve(....) and transferFrom(...) that permit a token owner 
    to give another address approval to transfer up to a number of tokens know as allowance

    Allowance for an address can only be set by the token owner

    Consider the allowance feature as the pocket money concept where we are given some amount by our parents are we are allowed to use only upto that
    amount or we can  also consider this as the credit system

    THis is a 2 step process where first the owner will call the approve() function and the approved account will call the transferFrom() function
    */

    //Implementing the allowance function from the interface

    function allowance(address tokenOwner, address spender) view public override returns(uint){
        return allowed[tokenOwner][spender];
    }

    //Next we need to implement the approve function this will be called by token owner which is the amount which can be set allowance which the amount
    //that can be spent by the spender
    function approve(address spender, uint tokens) public override returns (bool success){
        require(balances[msg.sender] >= tokens);
        require(tokens > 0); //The allowance must be greater than 0

        allowed[msg.sender][spender] = tokens;

        emit Approval(msg.sender,spender,tokens);
        return true;
    }

    //Now we implement the transferFrom method which allows the spender to withdraw or transfer tokens from owners account only till the value of tokens set
    function transferFrom(address from, address to, uint tokens) public virtual override returns (bool success){
        require(allowed[from][msg.sender] >= tokens);
        require(balances[from] >= tokens);
        balances[from] -= tokens;
        allowed[from][msg.sender] -= tokens;
        balances[to] += tokens;

        emit Transfer(from, to, tokens);
        return true;
    }


}

contract CryptosICO is Cryptos{
    address public admin;
    //This is the address where ETH will get transffered to when investors send it to the contract and cryptos is added to their balance
    address payable public deposit;
    uint tokenPrice = 0.001 ether;//1CRPT = 0.001ETH
    //There is a maximum amount of ether that can be invested and that is the HardCap 
    uint public hardCap = 300 ether;
    uint public raisedAmount;
    uint public saleStart = block.timestamp;
    uint public saleEnd = block.timestamp + 604800;//ICO ends in one week
    //Now we set the tokenSale trade time where it means when can they start trading with the CRYPTOS token
    uint public tokenTradeStart = saleEnd + 604800;
    uint public maxInvestment = 5 ether;
    uint public minInvestment = 0.1 ether;

    //Now we will set the state of the ICO
    enum State {beforeStart, running, afterEnd, halted}
    State public icoState;

    constructor(address payable _deposit){
        deposit = _deposit;
        admin = msg.sender;
        icoState = State.beforeStart;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin);
        _;
    }

    //In case if somethind bad happens or there is an emergency or they found an vulnearbility 
    function halt() public onlyAdmin{
        icoState = State.halted;
    }

    //If the ico is halted this function will let the admin resume the ICO
    function resume() public onlyAdmin{
        icoState = State.running;
    }

    //In case where the deposit address gets compromised and now this functon will let only the admin change the deposit address
    function changeDeposit(address payable newDeposit) public onlyAdmin{
        deposit = newDeposit;
    }

    function getCurrentState() public view returns(State){
        if(icoState == State.halted){
            return State.halted;
        }else if(block.timestamp < saleStart){
            return State.beforeStart;
        }else if(block.timestamp >= saleStart && block.timestamp <= saleEnd){
            return State.running;
        }else{
            return State.afterEnd;
        }
    }

    event Invest(address investor , uint value , uint tokens);

    //Now we need to implement the main function in the ICO the invest function
    function invest() payable public returns(bool){
        icoState = getCurrentState();
        require(icoState == State.running);

        require(msg.value >= minInvestment && msg.value <= maxInvestment);
        raisedAmount += msg.value;
        require(raisedAmount <= hardCap);

        uint tokens = msg.value/tokenPrice;

        //We need to add the token in the investor account and subract the same amount of tokens from the owners account
        balances[msg.sender] += tokens;
        balances[founder] -= tokens;
        deposit.transfer(msg.value);

        emit Invest(msg.sender,msg.value,tokens);
        return true;
    }

    receive() payable external{
        invest();
    }

    //We need to lockup tokens so that people who dont sell the tokens for just a profit
    function transfer(address to, uint tokens) public override returns(bool success){
        require(block.timestamp > tokenTradeStart);
        Cryptos.transfer(to,tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public override returns (bool success){
        require(block.timestamp > tokenTradeStart); // the token will be transferable only after tokenTradeStart
       
        Cryptos.transferFrom(from, to, tokens);  // same as super.transferFrom(to, tokens);
        return true;
    }

    //The tokens which were not sold in the ICO are burned in order to increase the price of the other tokens
    function burn() public returns(bool){
        icoState =  getCurrentState();
        require(icoState == State.afterEnd);
        balances[founder] = 0;
        return true;
    }
}
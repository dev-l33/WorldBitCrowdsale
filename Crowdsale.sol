pragma solidity ^0.4.18;

import "./Ownable.sol";
import "./oraclizeAPI_0.5.sol";

/**
 * @title Token
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
interface Token {
  function balanceOf(address who) external view returns (uint256);
  function transfer(address to, uint256 value) external;
}

/**
 * @title WorldBit Crowdsale 2.0
 */
contract Crowdsale is Ownable, usingOraclize {

    // The token being sold
    Token public token;

    // Address where funds are collected
    address public wallet;

    // USD price per coin
    uint public price;
    // USD ETH rate 1 eth = x USD ether
    uint public ethusd = 39598;

    // Amount of wei raised
    uint256 public weiRaised;

    // Amount of token sold
    uint256 public tokenSold;

    bool public enabled = true;

    // Price update frequency.
    uint public updatePriceFreq = 24 hours;
    // on/off price update
    bool updatePriceEnabled = true;

    /**
    * @param _token Address of the token being sold
    * @param _wallet Address where collected funds will be forwarded to
    * @param _price usd price per token
    */
    function Crowdsale(Token _token, address _wallet, uint _price) public {
        require(_wallet != address(0));
        require(_token != address(0));
        require(_price > 0);

        wallet = _wallet;
        token = Token(_token);
        price = _price;
    }

    /**
    * @dev fallback function ***DO NOT OVERRIDE***
    */
    function () external payable {
        buyTokens(msg.sender);
    }

    /**
    * @dev low level token purchase ***DO NOT OVERRIDE***
    * @param _beneficiary Address performing the token purchase
    */
    function buyTokens(address _beneficiary) public payable {

        uint256 weiAmount = msg.value;
        _preValidatePurchase(_beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        _processPurchase(_beneficiary, tokens);

        // update state
        weiRaised += weiAmount;
        tokenSold += tokens;

        _forwardFunds();
    }

    function withdrawToken(address _beneficiary, uint _tokenAmount) onlyOwner public {
        require(_beneficiary != address(0));
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    function enable(bool _enabled) onlyOwner external {
        enabled = _enabled;
    }

    /// @notice Allow users to buy tokens for `_price` USD
    /// @param _price price the users can sell to the contract
    function setPrice(uint256 _price) onlyOwner external {
        require(_price > 0);
        price = _price;
    }

    function setPriceUpdateFreq(uint _freq) onlyOwner external {
        updatePriceFreq = _freq;
    }

    function enablePriceUpdate(bool _updatePriceEnabled) onlyOwner external {
        updatePriceEnabled = _updatePriceEnabled;
    }

    /**
    * @dev Validation of an incoming purchase. Use require statemens to revert state when conditions are not met. Use super to concatenate validations.
    * @param _beneficiary Address performing the token purchase
    * @param _weiAmount Value in wei involved in the purchase
    */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) view internal {
        require(enabled);
        require(_beneficiary != address(0));
        require(_weiAmount > 0);
    }

    /**
    * @dev Override to extend the way in which ether is converted to tokens.
    * @param _weiAmount Value in wei to be converted into tokens
    * @return Number of tokens that can be purchased with the specified _weiAmount
    */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        return _weiAmount * ethusd / price;
    }

    /**
    * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
    * @param _beneficiary Address performing the token purchase
    * @param _tokenAmount Number of tokens to be emitted
    */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
        token.transfer(_beneficiary, _tokenAmount);
    }

    /**
    * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
    * @param _beneficiary Address receiving the tokens
    * @param _tokenAmount Number of tokens to be purchased
    */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        _deliverTokens(_beneficiary, _tokenAmount);
    }

    /**
    * @dev Determines how ETH is stored/forwarded on purchases.
    */
    function _forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    function __callback(bytes32 myid, string result) {
        require(msg.sender == oraclize_cbAddress());
        ethusd = parseInt(result, 2);
        updatePrice();
    }

    function updatePrice() public payable {
        if (updatePriceEnabled) {
            oraclize_query(updatePriceFreq, "URL", "json(https://api.etherscan.io/api?module=stats&action=ethprice&apikey=YourApiKeyToken).result.ethusd");
        }
    }
}
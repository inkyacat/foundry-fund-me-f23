// SPDX-License-Identifier: MIT

// 1. Pragma
pragma solidity ^0.8.18;

// 2. Imports
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

// 3. Interfaces, Libraries, Contracts
error FundMe__NotOwner();
error FundMe__NotEnoughEth();

contract FundMe {
    /* Type Declarations */
    using PriceConverter for uint256;

    /* State variables */
    uint256 public constant MINIMUM_USD = 5e19;
    address private immutable i_owner;
    address[] private s_funders;
    mapping(address => uint256) private s_addressToAmountFunded;
    AggregatorV3Interface private s_priceFeed;

    /* Modifiers */
    modifier onlyOwner() {
        // if else revert is better than require for gas
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    /* Constructor Function */
    constructor(address priceFeed) {
        s_priceFeed = AggregatorV3Interface(priceFeed); // typecasts the priceFeed address type variable as AggregatorV3Interface
        i_owner = msg.sender;
    }

    /* Functions */
    function fund() public payable {
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "You need to spend more ETH!");
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length; // gas optimized because we iterate through a memory variable and not a storage variable
        for (uint256 funderIndex = 0; funderIndex < fundersLength; funderIndex++) {
            address funder = s_funders[funderIndex]; // resets funders array
            s_addressToAmountFunded[funder] = 0; // resets funder address to funding value mapping
        }
        s_funders = new address[](0); // makes a new funders array

        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call Failed");
    }

    function withdraw() public onlyOwner {
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);

        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call Failed");
    }

    /* Getter Functions */
    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getFunder(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    function getAddressToAmountFunded(address fundingAddress) public view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }
}

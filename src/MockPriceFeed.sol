pragma solidity ^0.8.24;

contract MockPriceFeed {
    int256 public price;
    uint8 public constant DECIMALS = 8;

    constructor(int256 _price) {
        price = _price;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (0, price, block.timestamp, block.timestamp, 0);
    }

    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }
}
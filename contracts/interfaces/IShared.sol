// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}

interface IOracle {
    function getEthUsd() external view returns (uint256);
    function getBtcUsd() external view returns (uint256);
    function getSolUsd() external view returns (uint256);
    function getGoldPricePerGram() external view returns (uint256);
    function getSilverPricePerGram() external view returns (uint256);
    function getPlatinumPricePerGram() external view returns (uint256);
    function isStale() external view returns (bool);
}

interface IMintableToken {
    function ownerMint(address to, uint256 amount) external;
    function finalizeSeeding() external;
    function setOwner(address newOwner) external;
}

interface IRouterV3 {
    function addLiquidity(
        address tokenA, address tokenB,
        uint256 amountADesired, uint256 amountBDesired,
        uint256 amountAMin, uint256 amountBMin,
        address to, uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

interface ICommodityVault {
    function injectRewards(uint256 amount) external;
    function getRewardPool() external view returns (address);
}

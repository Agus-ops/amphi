// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}

interface IOracle {
    function ethUsd() external view returns (uint256);
    function btcUsd() external view returns (uint256);
    function getGoldPricePerGram() external view returns (uint256);
    function lastUpdate() external view returns (uint256);
    function STALENESS_THRESHOLD() external view returns (uint256);
}

interface IOracleFull {
    function ethUsd() external view returns (uint256);
    function btcUsd() external view returns (uint256);
    function getGoldPricePerGram() external view returns (uint256);
    function lastUpdate() external view returns (uint256);
    function STALENESS_THRESHOLD() external view returns (uint256);
}

interface IGoldVault {
    function injectRewards(uint256 amount) external;
    function lock(uint256 amount, uint256 duration) external;
}

interface IAmphiPair {
    function transferFrom(address, address, uint256) external;
    function mint(address) external returns (uint256);
    function burn(address) external returns (uint256, uint256);
    function swap(uint256, uint256, address) external;
    function getReserves() external view returns (uint112, uint112, uint32);
}

interface IAmphiFactory {
    function getPair(address, address) external view returns (address);
}

interface IMintableToken {
    function ownerMint(address to, uint256 amount) external;
    function finalizeSeeding() external;
    function setOwner(address newOwner) external;
}

interface IRouter {
    function addLiquidity(
        address tokenA, address tokenB,
        uint256 amountADesired, uint256 amountBDesired,
        uint256 amountAMin, uint256 amountBMin,
        address to, uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

contract SeedFinal is Script {
    // All existing Phase 1 addresses
    address constant DEPLOYER = 0xD2F9f6381Fb5f00c2fC606553592dB28309c019d;
    address constant MULTISIG = 0x384aeE987d59Af54182AD0ebFA94688FFf22F06b;
    address constant ORACLE   = 0xce201b600cd810D7e51ed2303C6900F8bA29101B;
    address constant FACTORY  = 0x83733B1313B2Ff0E1967193e9414EC2F77B093a9;
    address constant ROUTER   = 0xD8088e71314c2553cdD881EE0Fc186945f02A37a;
    address constant REGISTRY = 0xF7e4580875f0c33C266106d59f4d5ABdCa997fa3;

    // Pairs from Phase 1
    address constant PAIR_BTC = 0x1033880DeA5a528deAA24E0cC67F85d9bb82145e;
    address constant PAIR_ETH = 0x368417b93fdEF6e88b6b7a7a01627bFBc63bF78a;
    address constant PAIR_SOL = 0x9C340Cf9996027CFA88284cDA246d1E54aab4c53;
    address constant PAIR_GOLD = 0xD83f7d9324417c047E3Bb2091f211b1939B2A011;
    address constant PAIR_SILVER = 0x872BD34214381de88FC5292Cc4F7f68622E005c0;
    address constant PAIR_PLAT = 0x3445214f80A8ffC9549fa71277c27634bC570A79;

    // Tokens from Phase 1
    address constant USDC     = 0xcD722009ea2093806Ce7E225752F44e2Dd4E713E;
    address constant BTC      = 0xCD31115c3D142D76E65e161DCf9936b1daB94af2;
    address constant ETH      = 0x58b03878DDA6e060524d477b67AD985985642EC8;
    address constant SOL      = 0xc0359C22D44127a6dADabd3B65a17699f2F0287C;
    address constant GOLD     = 0x25Fdf52C4eF8cb665DB1F2c9B22a2dc64Ead2847;
    address constant SILVER   = 0x26709fE46EE5Acac9144b9A69B2e4399bC84A3DD;
    address constant PLATINUM = 0xe0b7f2554915807Fae5F2dB761a1A183C421b049;

    uint256 constant TARGET = 200_000;
    uint256 constant PRICE_DECIMALS = 1e8;
    uint256 constant TOKEN_DECIMALS = 1e18;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // 1. Read Oracle prices (already set by keeper)
        (bool ok1, bytes memory ethData) = ORACLE.call(abi.encodeWithSignature("getEthUsd()"));
        (bool ok2, bytes memory btcData) = ORACLE.call(abi.encodeWithSignature("getBtcUsd()"));
        (bool ok3, bytes memory solData) = ORACLE.call(abi.encodeWithSignature("getSolUsd()"));
        (bool ok4, bytes memory goldData) = ORACLE.call(abi.encodeWithSignature("getGoldPricePerGram()"));
        (bool ok5, bytes memory silverData) = ORACLE.call(abi.encodeWithSignature("getSilverPricePerGram()"));
        (bool ok6, bytes memory platData) = ORACLE.call(abi.encodeWithSignature("getPlatinumPricePerGram()"));
        require(ok1 && ok2 && ok3 && ok4 && ok5 && ok6, "Oracle read failed");

        uint256 ethPrice = abi.decode(ethData, (uint256));
        uint256 btcPrice = abi.decode(btcData, (uint256));
        uint256 solPrice = abi.decode(solData, (uint256));
        uint256 goldPrice = abi.decode(goldData, (uint256));
        uint256 silverPrice = abi.decode(silverData, (uint256));
        uint256 platinumPrice = abi.decode(platData, (uint256));

        console.log("Oracle prices:");
        console.log("ETH:", ethPrice);
        console.log("BTC:", btcPrice);
        console.log("SOL:", solPrice);
        console.log("Gold/gram:", goldPrice);
        console.log("Silver/gram:", silverPrice);
        console.log("Platinum/gram:", platinumPrice);

        // 2. Calculate token amounts
        uint256 usdcAmt = TARGET * TOKEN_DECIMALS;
        uint256 btcAmt  = (TARGET * TOKEN_DECIMALS * PRICE_DECIMALS) / btcPrice;
        uint256 ethAmt  = (TARGET * TOKEN_DECIMALS * PRICE_DECIMALS) / ethPrice;
        uint256 solAmt  = (TARGET * TOKEN_DECIMALS * PRICE_DECIMALS) / solPrice;
        uint256 goldAmt = (TARGET * TOKEN_DECIMALS * TOKEN_DECIMALS) / goldPrice;
        uint256 silverAmt = (TARGET * TOKEN_DECIMALS * TOKEN_DECIMALS) / silverPrice;
        uint256 platAmt = (TARGET * TOKEN_DECIMALS * TOKEN_DECIMALS) / platinumPrice;

        // 3. Mint all tokens to deployer via ownerMint (deployer still owns them)
        _mint(USDC, usdcAmt * 6);
        _mint(BTC, btcAmt);
        _mint(ETH, ethAmt);
        _mint(SOL, solAmt);
        _mint(GOLD, goldAmt);
        _mint(SILVER, silverAmt);
        _mint(PLATINUM, platAmt);

        // 4. Approve Router for all tokens
        _approve(USDC, ROUTER, usdcAmt * 6);
        _approve(BTC, ROUTER, btcAmt);
        _approve(ETH, ROUTER, ethAmt);
        _approve(SOL, ROUTER, solAmt);
        _approve(GOLD, ROUTER, goldAmt);
        _approve(SILVER, ROUTER, silverAmt);
        _approve(PLATINUM, ROUTER, platAmt);

        // 5. Add liquidity to existing pairs
        uint256 deadline = block.timestamp + 1200;
        _addLiq(USDC, BTC, usdcAmt, btcAmt, deadline);
        _addLiq(USDC, ETH, usdcAmt, ethAmt, deadline);
        _addLiq(USDC, SOL, usdcAmt, solAmt, deadline);
        _addLiq(USDC, GOLD, usdcAmt, goldAmt, deadline);
        _addLiq(USDC, SILVER, usdcAmt, silverAmt, deadline);
        _addLiq(USDC, PLATINUM, usdcAmt, platAmt, deadline);

        console.log("All 6 pairs seeded with ~$200K/side!");

        // 6. Finalize all tokens (lock ownerMint)
        _finalize(USDC);
        _finalize(BTC);
        _finalize(ETH);
        _finalize(SOL);
        _finalize(GOLD);
        _finalize(SILVER);
        _finalize(PLATINUM);
        console.log("Tokens finalized.");

        // 7. Transfer governance
        (bool fok,) = FACTORY.call(abi.encodeWithSignature("setOwner(address)", MULTISIG));
        require(fok, "Factory governance failed");
        (bool rok,) = REGISTRY.call(abi.encodeWithSignature("transferOwnership(address)", MULTISIG));
        require(rok, "Registry governance failed");
        console.log("Governance transferred to Multisig.");

        vm.stopBroadcast();
    }

    function _mint(address token, uint256 amount) internal {
        (bool ok,) = token.call(abi.encodeWithSignature("ownerMint(address,uint256)", DEPLOYER, amount));
        require(ok, "Mint failed");
    }

    function _approve(address token, address spender, uint256 amount) internal {
        (bool ok,) = token.call(abi.encodeWithSignature("approve(address,uint256)", spender, amount));
        require(ok, "Approve failed");
    }

    function _addLiq(address a, address b, uint256 amtA, uint256 amtB, uint256 deadline) internal {
        (bool ok,) = ROUTER.call(abi.encodeWithSignature(
            "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
            a, b, amtA, amtB, 0, 0, DEPLOYER, deadline
        ));
        require(ok, "addLiquidity failed");
    }

    function _finalize(address token) internal {
        (bool ok,) = token.call(abi.encodeWithSignature("finalizeSeeding()"));
        require(ok, "Finalize failed");
    }
}

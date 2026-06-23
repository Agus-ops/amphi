// SPDX-License-Identifier: MIT
import "../contracts/AmphiMultisig.sol";
import "../contracts/AmphiOracle.sol";
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/MockERC20.sol";
import "../contracts/AmphiFactory.sol";
import "../contracts/AmphiRouterV3.sol";
import "../contracts/RewardPool.sol";
import "../contracts/CommodityVault.sol";
import "../contracts/PremiumCommodityFaucet.sol";
import "../contracts/OracleFaucet.sol";
import "../contracts/AmphiRegistry.sol";
import "../contracts/PoolSeederV2.sol";

contract FullDeploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        // ============================================================
        // STEP 1: MULTISIG
        // ============================================================
        address[] memory owners = new address[](1);
        owners[0] = msg.sender;
        AmphiMultisig multisig = new AmphiMultisig(owners, 1);
        console.log("Multisig:", address(multisig));

        // ============================================================
        // STEP 2: ORACLE
        // ============================================================
        AmphiOracle oracle = new AmphiOracle(msg.sender, address(multisig));
        console.log("Oracle:", address(oracle));

        // ============================================================
        // STEP 3: 7 TOKEN
        // ============================================================
        MockERC20 usdc = new MockERC20("Mock USDC", "mUSDC", msg.sender, 1500000 * 1e18);
        console.log("mUSDC:", address(usdc));
        MockERC20 btc  = new MockERC20("Mock Bitcoin", "mBTC", msg.sender, 30 * 1e18);
        console.log("mBTC:", address(btc));
        MockERC20 eth_ = new MockERC20("Mock Ethereum", "mETH", msg.sender, 500 * 1e18);
        console.log("mETH:", address(eth_));
        MockERC20 sol  = new MockERC20("Mock Solana", "mSOL", msg.sender, 12000 * 1e18);
        console.log("mSOL:", address(sol));
        MockERC20 gold = new MockERC20("Mock Gold", "mGold", msg.sender, 20000 * 1e18);
        console.log("mGold:", address(gold));
        MockERC20 silver = new MockERC20("Mock Silver", "mSilver", msg.sender, 1500000 * 1e18);
        console.log("mSilver:", address(silver));
        MockERC20 platinum = new MockERC20("Mock Platinum", "mPlatinum", msg.sender, 50000 * 1e18);
        console.log("mPlatinum:", address(platinum));

        // ============================================================
        // STEP 4: FACTORY + ROUTER
        // ============================================================
        AmphiFactory factory = new AmphiFactory();
        console.log("Factory:", address(factory));
        AmphiRouterV3 router = new AmphiRouterV3(address(factory));
        console.log("Router:", address(router));

        // ============================================================
        // STEP 5: CREATE 6 PAIRS
        // ============================================================
        address pairBTC = factory.createPair(address(usdc), address(btc));
        address pairETH = factory.createPair(address(usdc), address(eth_));
        address pairSOL = factory.createPair(address(usdc), address(sol));
        address pairGold = factory.createPair(address(usdc), address(gold));
        address pairSilver = factory.createPair(address(usdc), address(silver));
        address pairPlat = factory.createPair(address(usdc), address(platinum));
        console.log("Pairs created");

        // ============================================================
        // STEP 6: REWARD POOLS + VAULTS
        // ============================================================
        RewardPool rGold = new RewardPool(msg.sender);
        RewardPool rSilver = new RewardPool(msg.sender);
        RewardPool rPlat = new RewardPool(msg.sender);
        CommodityVault vGold = new CommodityVault(address(gold), address(rGold), msg.sender);
        CommodityVault vSilver = new CommodityVault(address(silver), address(rSilver), msg.sender);
        CommodityVault vPlat = new CommodityVault(address(platinum), address(rPlat), msg.sender);
        rGold.setVault(address(vGold));
        rSilver.setVault(address(vSilver));
        rPlat.setVault(address(vPlat));
        console.log("RewardPools + Vaults created");

        // ============================================================
        // STEP 7: PREMIUM FAUCET
        // ============================================================
        PremiumCommodityFaucet premium = new PremiumCommodityFaucet(
            address(gold), address(silver), address(platinum),
            address(oracle),
            address(vGold), address(vSilver), address(vPlat),
            address(multisig)
        );
        vGold.setAuthorizedInjector(address(premium));
        vSilver.setAuthorizedInjector(address(premium));
        vPlat.setAuthorizedInjector(address(premium));
        console.log("PremiumFaucet:", address(premium));

        // ============================================================
        // STEP 8: ORACLE FAUCET
        // ============================================================
        OracleFaucet faucet = new OracleFaucet(
            address(usdc), address(btc), address(eth_), address(sol),
            address(gold), address(silver), address(platinum),
            address(oracle)
        );
        console.log("OracleFaucet:", address(faucet));

        // ============================================================
        // STEP 9: SET MINTERS
        // ============================================================
        usdc.setMinter(address(faucet), true);
        btc.setMinter(address(faucet), true);
        eth_.setMinter(address(faucet), true);
        sol.setMinter(address(faucet), true);
        gold.setMinter(address(faucet), true);
        silver.setMinter(address(faucet), true);
        platinum.setMinter(address(faucet), true);
        gold.setMinter(address(premium), true);
        silver.setMinter(address(premium), true);
        platinum.setMinter(address(premium), true);
        console.log("Minters set");

        // ============================================================
        // STEP 10: REGISTRY
        // ============================================================
        AmphiRegistry registry = new AmphiRegistry();
        registry.registerToken(address(usdc), "mUSDC");
        registry.registerToken(address(btc), "mBTC");
        registry.registerToken(address(eth_), "mETH");
        registry.registerToken(address(sol), "mSOL");
        registry.registerToken(address(gold), "mGold");
        registry.registerToken(address(silver), "mSilver");
        registry.registerToken(address(platinum), "mPlatinum");
        registry.registerPool(pairBTC, address(usdc), address(btc));
        registry.registerPool(pairETH, address(usdc), address(eth_));
        registry.registerPool(pairSOL, address(usdc), address(sol));
        registry.registerPool(pairGold, address(usdc), address(gold));
        registry.registerPool(pairSilver, address(usdc), address(silver));
        registry.registerPool(pairPlat, address(usdc), address(platinum));
        console.log("Registry:", address(registry));

        // ============================================================
        // STEP 11: POOLSEEDERV2
        // ============================================================
        PoolSeederV2 seeder = new PoolSeederV2(
            address(oracle), address(router), address(multisig),
            address(usdc), address(btc), address(eth_), address(sol),
            address(gold), address(silver), address(platinum)
        );
        console.log("Seeder:", address(seeder));

        // ============================================================
        // STEP 12: TRANSFER TOKEN OWNERSHIP TO SEEDER
        // ============================================================
        usdc.setOwner(address(seeder));
        btc.setOwner(address(seeder));
        eth_.setOwner(address(seeder));
        sol.setOwner(address(seeder));
        gold.setOwner(address(seeder));
        silver.setOwner(address(seeder));
        platinum.setOwner(address(seeder));
        console.log("Token ownership -> Seeder");

        // ============================================================
        // STEP 13: SEED ALL POOLS (HEAVY TX)
        // ============================================================
        console.log("Executing seedAll()... (heavy tx)");
        seeder.seedAll(pairBTC, pairETH, pairSOL, pairGold, pairSilver, pairPlat);
        console.log("Seeding complete!");

        // ============================================================
        // STEP 14: TRANSFER GOVERNANCE
        // ============================================================
        factory.proposeOwner(address(multisig));
        registry.transferOwnership(address(multisig));
        console.log("Governance -> Multisig");

        vm.stopBroadcast();

        console.log("==========================================");
        console.log(" AMPHI V1.0.0 -- FULL DEPLOY COMPLETE");
        console.log("==========================================");
        console.log("Multisig:", address(multisig));
        console.log("Oracle:", address(oracle));
        console.log("USDC:", address(usdc));
        console.log("BTC:", address(btc));
        console.log("ETH:", address(eth_));
        console.log("SOL:", address(sol));
        console.log("Gold:", address(gold));
        console.log("Silver:", address(silver));
        console.log("Platinum:", address(platinum));
        console.log("Factory:", address(factory));
        console.log("Router:", address(router));
        console.log("RewardGold:", address(rGold));
        console.log("RewardSilver:", address(rSilver));
        console.log("RewardPlat:", address(rPlat));
        console.log("VaultGold:", address(vGold));
        console.log("VaultSilver:", address(vSilver));
        console.log("VaultPlat:", address(vPlat));
        console.log("Premium:", address(premium));
        console.log("Faucet:", address(faucet));
        console.log("Registry:", address(registry));
        console.log("Seeder:", address(seeder));
    }
}

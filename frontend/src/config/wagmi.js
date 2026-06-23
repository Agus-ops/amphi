import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { GIWA_SEPOLIA } from "./chains";

export const wagmiConfig = getDefaultConfig({
  appName: "Amphi",
  // Project ID WalletConnect dari .env (VITE_WC_PROJECT_ID)
  projectId: import.meta.env.VITE_WC_PROJECT_ID || "YOUR_PROJECT_ID_HERE", 
  chains: [GIWA_SEPOLIA],
  ssr: false, 
});

export const GIWA_SEPOLIA = {
  id: 91342,
  name: 'GIWA Sepolia',
  network: 'giwa-sepolia',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['https://sepolia-rpc.giwa.io'] },
    public: { http: ['https://sepolia-rpc.giwa.io'] },
  },
  blockExplorers: {
    default: { name: 'GIWA Explorer', url: 'https://sepolia-explorer.giwa.io' },
  },
  testnet: true,
};

// Shortcut supaya komponen lama yang masih pakai GIWA_SEPOLIA.explorerUrl tetap jalan.
GIWA_SEPOLIA.explorerUrl = GIWA_SEPOLIA.blockExplorers.default.url;

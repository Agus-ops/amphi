import { useReadContracts } from 'wagmi';
import { REGISTRY, TOKENS } from '../contracts/contracts';
import { REGISTRY_ABI } from '../contracts/abis';

const ALL_TOKENS = Object.entries(TOKENS); // [['mUSDC', '0x...'], ...]

export function useOfficialTokens() {
  const { data, isLoading } = useReadContracts({
    contracts: ALL_TOKENS.map(([, addr]) => ({
      address: REGISTRY,
      abi: REGISTRY_ABI,
      functionName: 'isOfficialToken',
      args: [addr],
    })),
    query: {
      refetchInterval: 30000,
      staleTime: 60000,
    },
  });

  const officialTokens = ALL_TOKENS
    .map(([symbol, address], i) => ({
      symbol,
      address,
      isOfficial: data?.[i]?.result === true,
    }))
    .filter((t) => t.isOfficial);

  return { officialTokens, isLoading };
}

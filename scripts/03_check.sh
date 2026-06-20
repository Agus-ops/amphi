#!/bin/bash
source /opt/amphi/.env
RPC=$GIWA_RPC_URL

echo "=== USDC/BTC ==="
cast call 0x3E02a0a8d9D4C7594CC93d142bcC101688f75971 "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC

echo "=== USDC/ETH ==="
cast call 0x860C6E5b1C2aAC1036B73cce90df5C40Fc176b22 "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC

echo "=== USDC/Gold ==="
cast call 0xdd5bFA90A717993e8ec7D3704D8FdEF5e72B4D57 "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC

echo "=== Oracle harga sekarang ==="
ORACLE=0xFF5A696a85734205360A04D0005Eb666dE7a9B08
echo "ethUsd: $(cast call $ORACLE "ethUsd()(uint256)" --rpc-url $RPC)"
echo "btcUsd: $(cast call $ORACLE "btcUsd()(uint256)" --rpc-url $RPC)"
echo "goldPricePerGram: $(cast call $ORACLE "getGoldPricePerGram()(uint256)" --rpc-url $RPC)"

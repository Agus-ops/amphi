#!/bin/bash
set -e
source /opt/amphi/.env
RPC=$GIWA_RPC_URL
PK=$PRIVATE_KEY
MAIN_WALLET=0xD2F9f6381Fb5f00c2fC606553592dB28309c019d

ROUTER=0x809b489a92E007B3C7c8F9914e89D091a4Ce381d
USDC=0x31783d58369E5308174a13c264076ef8938260Bb
ETH=0x01f79590Ce1359f4Ae5863057Fa0538a9B399e83
GOLD=0x1edB1E3C0740d3E371ecf0F5bB5af2E028afE6bc

echo ">>> Approve Router"
cast send $ETH "approve(address,uint256)" $ROUTER 2000000000000000000 --private-key $PK --rpc-url $RPC
sleep 8
cast send $USDC "approve(address,uint256)" $ROUTER 3500000000000000000000 --private-key $PK --rpc-url $RPC
sleep 8

DEADLINE=$(($(date +%s) + 600))

echo ">>> Swap ETH -> USDC (fix pool USDC/ETH)"
cast send $ROUTER "swapExactTokensForTokens(uint256,uint256,address,address,address,uint256)" \
  1700000000000000000 0 $ETH $USDC $MAIN_WALLET $DEADLINE \
  --private-key $PK --rpc-url $RPC
sleep 10

echo ">>> Swap USDC -> GOLD (fix pool USDC/Gold)"
cast send $ROUTER "swapExactTokensForTokens(uint256,uint256,address,address,address,uint256)" \
  3290000000000000000000 0 $USDC $GOLD $MAIN_WALLET $DEADLINE \
  --private-key $PK --rpc-url $RPC
sleep 10

echo ">>> SELESAI SWAP"

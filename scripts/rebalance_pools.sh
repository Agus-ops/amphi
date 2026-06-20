#!/bin/bash
set -e
source /opt/amphi/.env
RPC=$GIWA_RPC_URL
PK=$PRIVATE_KEY
MAIN_WALLET=0xD2F9f6381Fb5f00c2fC606553592dB28309c019d

FAUCET=0x2b1451b7A8F5C60B6A4bea112854c6aF536Fcf83
ROUTER=0x809b489a92E007B3C7c8F9914e89D091a4Ce381d
USDC=0x31783d58369E5308174a13c264076ef8938260Bb
BTC=0x8a96fB4D38715c152092271fa9a86fd97A029045
ETH=0x01f79590Ce1359f4Ae5863057Fa0538a9B399e83
GOLD=0x1edB1E3C0740d3E371ecf0F5bB5af2E028afE6bc

echo ">>> FASE 1: Farming 7 wallet baru via OracleFaucet"
for i in $(seq 1 7); do
  echo "--- Wallet $i ---"
  WALLET_JSON=$(cast wallet new --json 2>/dev/null)
  W=$(echo "$WALLET_JSON" | jq -r '.[0].address')
  P=$(echo "$WALLET_JSON" | jq -r '.[0].private_key')

  cast send "$W" --value 0.03ether --private-key "$PK" --rpc-url "$RPC" >/dev/null
  sleep 10

  cast send "$FAUCET" "claim()" --private-key "$P" --rpc-url "$RPC" >/dev/null
  sleep 8

  # Consolidate ke wallet utama
  for TOKEN in $USDC $BTC $ETH $GOLD; do
    BAL=$(cast call "$TOKEN" "balanceOf(address)(uint256)" "$W" --rpc-url "$RPC" | head -1 | tr -d '\n')
    if [ "$BAL" != "0" ]; then
      cast send "$TOKEN" "transfer(address,uint256)" "$MAIN_WALLET" "$BAL" --private-key "$P" --rpc-url "$RPC" >/dev/null
      sleep 5
    fi
  done
  echo "Wallet $i selesai, token sudah dipindah ke wallet utama."
done

echo ">>> FASE 2: Cek saldo wallet utama setelah konsolidasi"
echo "USDC: $(cast call $USDC "balanceOf(address)(uint256)" $MAIN_WALLET --rpc-url $RPC)"
echo "ETH : $(cast call $ETH "balanceOf(address)(uint256)" $MAIN_WALLET --rpc-url $RPC)"
echo "GOLD: $(cast call $GOLD "balanceOf(address)(uint256)" $MAIN_WALLET --rpc-url $RPC)"

echo ">>> FASE 3: Approve Router"
cast send $ETH "approve(address,uint256)" $ROUTER 2000000000000000000 --private-key $PK --rpc-url $RPC >/dev/null
sleep 5
cast send $USDC "approve(address,uint256)" $ROUTER 3500000000000000000000 --private-key $PK --rpc-url $RPC >/dev/null
sleep 5

echo ">>> FASE 4: Swap rebalance"
DEADLINE=$(($(date +%s) + 600))

echo "Swap ETH -> USDC (fix pool USDC/ETH)..."
cast send $ROUTER "swapExactTokensForTokens(uint256,uint256,address,address,address,uint256)" \
  1700000000000000000 0 $ETH $USDC $MAIN_WALLET $DEADLINE \
  --private-key $PK --rpc-url $RPC
sleep 8

echo "Swap USDC -> GOLD (fix pool USDC/Gold)..."
cast send $ROUTER "swapExactTokensForTokens(uint256,uint256,address,address,address,uint256)" \
  3290000000000000000000 0 $USDC $GOLD $MAIN_WALLET $DEADLINE \
  --private-key $PK --rpc-url $RPC
sleep 8

echo ">>> FASE 5: Cek reserve final ketiga pool"
for PAIR in 0x3E02a0a8d9D4C7594CC93d142bcC101688f75971 0x860C6E5b1C2aAC1036B73cce90df5C40Fc176b22 0xdd5bFA90A717993e8ec7D3704D8FdEF5e72B4D57; do
  echo "Pair $PAIR reserves:"
  cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC
done

echo ">>> SELESAI"

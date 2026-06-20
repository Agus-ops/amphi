#!/bin/bash
set -e
source /opt/amphi/.env
RPC=$GIWA_RPC_URL
PK=$PRIVATE_KEY
MAIN_WALLET=0xD2F9f6381Fb5f00c2fC606553592dB28309c019d

FAUCET=0x2b1451b7A8F5C60B6A4bea112854c6aF536Fcf83
USDC=0x31783d58369E5308174a13c264076ef8938260Bb
BTC=0x8a96fB4D38715c152092271fa9a86fd97A029045
ETH=0x01f79590Ce1359f4Ae5863057Fa0538a9B399e83
GOLD=0x1edB1E3C0740d3E371ecf0F5bB5af2E028afE6bc

for i in $(seq 1 7); do
  echo "--- Wallet $i ---"
  WALLET_JSON=$(cast wallet new --json 2>/dev/null)
  W=$(echo "$WALLET_JSON" | jq -r '.[0].address')
  P=$(echo "$WALLET_JSON" | jq -r '.[0].private_key')

  cast send "$W" --value 0.03ether --private-key "$PK" --rpc-url "$RPC" >/dev/null
  sleep 10

  cast send "$FAUCET" "claim()" --private-key "$P" --rpc-url "$RPC" >/dev/null
  sleep 8

  for TOKEN in $USDC $BTC $ETH $GOLD; do
    BAL=$(cast call "$TOKEN" "balanceOf(address)(uint256)" "$W" --rpc-url "$RPC")
    BAL=$(echo "$BAL" | head -1 | awk '{print $1}')
    if [ "$BAL" != "0" ]; then
      cast send "$TOKEN" "transfer(address,uint256)" "$MAIN_WALLET" "$BAL" --private-key "$P" --rpc-url "$RPC" >/dev/null
      sleep 5
    fi
  done
  echo "Wallet $i selesai."
done

echo ">>> Saldo wallet utama sekarang:"
echo "USDC: $(cast call $USDC "balanceOf(address)(uint256)" $MAIN_WALLET --rpc-url $RPC)"
echo "ETH : $(cast call $ETH "balanceOf(address)(uint256)" $MAIN_WALLET --rpc-url $RPC)"
echo "GOLD: $(cast call $GOLD "balanceOf(address)(uint256)" $MAIN_WALLET --rpc-url $RPC)"

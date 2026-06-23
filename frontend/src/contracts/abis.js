export const ERC20_ABI = [
  { type:'function', name:'balanceOf', inputs:[{name:'owner',type:'address'}], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'approve', inputs:[{name:'spender',type:'address'},{name:'amount',type:'uint256'}], outputs:[{name:'',type:'bool'}], stateMutability:'nonpayable' },
  { type:'function', name:'allowance', inputs:[{name:'owner',type:'address'},{name:'spender',type:'address'}], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'decimals', inputs:[], outputs:[{name:'',type:'uint8'}], stateMutability:'view' },
  { type:'function', name:'symbol', inputs:[], outputs:[{name:'',type:'string'}], stateMutability:'view' },
  { type:'function', name:'name', inputs:[], outputs:[{name:'',type:'string'}], stateMutability:'view' }
];

export const ROUTER_ABI = [
  { type:'function', name:'addLiquidity', inputs:[ {name:'tokenA',type:'address'},{name:'tokenB',type:'address'}, {name:'amountADesired',type:'uint256'},{name:'amountBDesired',type:'uint256'}, {name:'amountAMin',type:'uint256'},{name:'amountBMin',type:'uint256'}, {name:'to',type:'address'},{name:'deadline',type:'uint256'} ], outputs:[{name:'amountA',type:'uint256'},{name:'amountB',type:'uint256'},{name:'liquidity',type:'uint256'}], stateMutability:'nonpayable' },
  { type:'function', name:'swapExactTokensForTokens', inputs:[ {name:'amountIn',type:'uint256'},{name:'amountOutMin',type:'uint256'}, {name:'path',type:'address[]'},{name:'to',type:'address'},{name:'deadline',type:'uint256'} ], outputs:[{name:'amountOut',type:'uint256'}], stateMutability:'nonpayable' }
];

export const FAUCET_ABI = [
  { type:'function', name:'claim', inputs:[], outputs:[], stateMutability:'nonpayable' },
  { type:'function', name:'claimed', inputs:[{name:'',type:'address'}], outputs:[{name:'',type:'bool'}], stateMutability:'view' }
];

export const PREMIUM_ABI = [
  { type:'function', name:'mintGold', inputs:[], outputs:[], stateMutability:'payable' },
  { type:'function', name:'mintSilver', inputs:[], outputs:[], stateMutability:'payable' },
  { type:'function', name:'mintPlatinum', inputs:[], outputs:[], stateMutability:'payable' },
  { type:'function', name:'TARGET_USD_PER_TX', inputs:[], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'MAX_DAILY_USD', inputs:[], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'dailySpent', inputs:[{name:'',type:'address'}], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'lastDay', inputs:[{name:'',type:'address'}], outputs:[{name:'',type:'uint256'}], stateMutability:'view' }
];

export const VAULT_ABI = [
  { type:'function', name:'lock', inputs:[{name:'amount',type:'uint256'},{name:'duration',type:'uint256'}], outputs:[], stateMutability:'nonpayable' },
  { type:'function', name:'unlock', inputs:[], outputs:[], stateMutability:'nonpayable' },
  { type:'function', name:'claimReward', inputs:[], outputs:[], stateMutability:'nonpayable' },
  { type:'function', name:'pendingReward', inputs:[{name:'user',type:'address'}], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'positions', inputs:[{name:'',type:'address'}], outputs:[{name:'amount',type:'uint256'},{name:'weight',type:'uint256'},{name:'unlockTime',type:'uint256'},{name:'rewardPerWeightPaid',type:'uint256'}], stateMutability:'view' }
];

export const FACTORY_ABI = [
  { type:'function', name:'getPair', inputs:[{name:'',type:'address'},{name:'',type:'address'}], outputs:[{name:'',type:'address'}], stateMutability:'view' }
];

export const ORACLE_ABI = [
  { type:'function', name:'isStale', inputs:[], outputs:[{name:'',type:'bool'}], stateMutability:'view' },
  { type:'function', name:'getEthUsd', inputs:[], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'getBtcUsd', inputs:[], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'getSolUsd', inputs:[], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'getGoldPricePerGram', inputs:[], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'getSilverPricePerGram', inputs:[], outputs:[{name:'',type:'uint256'}], stateMutability:'view' },
  { type:'function', name:'getPlatinumPricePerGram', inputs:[], outputs:[{name:'',type:'uint256'}], stateMutability:'view' }
];

export const REGISTRY_ABI = [
  { type:'function', name:'isOfficialToken', inputs:[{name:'',type:'address'}], outputs:[{name:'',type:'bool'}], stateMutability:'view' },
  { type:'function', name:'isOfficialPool', inputs:[{name:'',type:'address'}], outputs:[{name:'',type:'bool'}], stateMutability:'view' }
];

export const REWARD_POOL_ABI = [
  { type:'function', name:'totalRewards', inputs:[], outputs:[{name:'',type:'uint256'}], stateMutability:'view' }
];

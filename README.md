> Deploy contracts : 

forge script script/DeployGoldToken.s.sol:DeployGoldToken \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY

> GoldLottery deployed at: 0x18715183248AAef4687DEC37fBF792C1412b3b0B
> GoldToken deployed at: 0xa360ecF90b6d94Edee7B1cA9447421A4F98b59A3

> Send some ETH to the tokencontract

cast send 0x18715183248AAef4687DEC37fBF792C1412b3b0B \
    --value 0.01ether \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL

> Check goldToken contract's balance :

cast balance 0x18715183248AAef4687DEC37fBF792C1412b3b0B --rpc-url $RPC_URL

> Check lottery contract's balance :

cast call 0x18715183248AAef4687DEC37fBF792C1412b3b0B \
    "lotteryBalance()(uint256)" \
    --rpc-url $RPC_URL

> Check participants in the lottery : 

cast call 0x18715183248AAef4687DEC37fBF792C1412b3b0B "getParticipants()" --rpc-url $RPC_URL

> Check his % of chances :

cast call 0x18715183248AAef4687DEC37fBF792C1412b3b0B \
    "getChances(address)(uint256)" \
    0xF389635f844DaA5051aF879a00077C6C9F2aA345 \
    --rpc-url $RPC_URL


===============parti ju : =========================

forge script script/DeployGoldToken.s.sol:DeployGoldToken     --rpc-url $RPC_URL_SEPOLIA     --private-key $PRIVATE_KEY     --broadcast     --verify     --etherscan-api-key $ETHERSCAN_API_KEY

Script ran successfully.



== Logs ==
Created VRF subscription: 21590261458706400825049526808212813833048271768527266645185995564925556330768

Deployed Lottery at: 0xC665024dcBAACF27AFfa62eb0F968D81E433AF92
  Deployed on Sepolia:
  Token: 0x669120365b50362392a920f914Af459Dd6e824B9
  Bridge: 0x48cBc32bE61D5Cb8Ab197C292Cd71fc0A2b5f8Db

== Logs ==
  Deployed on BSC Testnet:
  Token: 0x519fFbc64fc99825c25F6cb8AEC8e6554BFda613
  Bridge: 0x15cCd345a828113104E48Aef6f63F4d7Ac4da2AE
  Router: 0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f
  LINK: 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06

cast send 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06   "transfer(address,uint256)"   0xD5FC983aFD9B836a99FB4f1cbACcD3b1201bC051   5000000000000000000   --rpc-url "$RPC_URL_BSC_TESTNET"   --private-key "$PRIVATE_KEY"

====================== MODE D'EMPLOI =========================

# Configurer l'adresse du contrat BSC dans le GoldBridge Sepolia
cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY \
    0xC482ab757Bcd25914E33Af8FD043EB8410150f7D \
    "setRemoteContract(bytes)" \
    $(cast abi-encode "f(address)" 0x40f35685b9e6F3F4d567224B6470d0a60581eB79)

# Configurer le chainId de BSC Testnet (97)
cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY \
    0xC482ab757Bcd25914E33Af8FD043EB8410150f7D \
    "setDestinationChainId(uint64)" 97

    # Configurer l'adresse du contrat Sepolia dans le GoldBridgeBSC
cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY \
    0x40f35685b9e6F3F4d567224B6470d0a60581eB79 \
    "setRemoteContract(bytes)" \
    $(cast abi-encode "f(address)" 0xC482ab757Bcd25914E33Af8FD043EB8410150f7D)

# Configurer le chainId de Sepolia (11155111)
cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY \
    0x40f35685b9e6F3F4d567224B6470d0a60581eB79 \
    "setSepoliaChainId(uint64)" 11155111

# Configurer l'adresse source autorisée
cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY \
    0x40f35685b9e6F3F4d567224B6470d0a60581eB79 \
    "setAuthorizedSourceAddress(address)" \
    0xC482ab757Bcd25914E33Af8FD043EB8410150f7D

    # Envoyer des ETH au bridge Sepolia
cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY \
    0xC482ab757Bcd25914E33Af8FD043EB8410150f7D \
    --value 0.1ether

# Envoyer des BNB au bridge BSC
cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY \
    0x40f35685b9e6F3F4d567224B6470d0a60581eB79 \
    --value 0.1ether
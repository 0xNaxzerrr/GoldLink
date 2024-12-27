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
  Created subscription with ID: 12223
  Funded subscription with 2 LINK
  Added GoldLottery as consumer to subscription

Sepolia - GoldLottery: 0xB4117EbD882C0358d3438d5121Bf813AE0F7Ff6D
Sepolia - GoldToken: 0xaBFd99e71b41Bf494858A576215c165FA54Db955
Sepolia - GoldBridge: 0xC482ab757Bcd25914E33Af8FD043EB8410150f7D


== Logs ==
  BSC - GoldTokenBSC deployed at: 0x205045D7dDb69bd6348129a445C9237B4b3c851E
  BSC - GoldBridgeBSC deployed at: 0x40f35685b9e6F3F4d567224B6470d0a60581eB79


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
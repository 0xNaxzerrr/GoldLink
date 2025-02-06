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
  Created VRF subscription: 72505492050481404530201281463226024964224110164911129287313511204618353878730
  Created VRF subscription (hex): 72505492050481404530201281463226024964224110164911129287313511204618353878730
  Created VRF subscription (dec): 72505492050481404530201281463226024964224110164911129287313511204618353878730
  Funded subscription with 2eth
  Added Lottery as VRF consumer
  Deployed contracts:
  Lottery: 0xdD6e6C295eB874B9A801110C0d4627D0cD12d875
  Token: 0x4DE2DF46C1B8902435EAaC826D5D5497BB6CE467
  Bridge: 0x3602187ff4Ad98C6f5d27e71655939886fBf5432


== Logs ==
  BSC - GoldTokenBSC deployed at: 0x02FACFc2cd5E273baA543FA4afC4f77DC0E6c891
  BSC - GoldBridgeBSC deployed at: 0x400a5f8D3636A697973f5be14B222de8aa3074d7


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
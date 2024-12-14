> Deploy contracts : 

forge script script/DeployGoldToken.s.sol:DeployGoldToken \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY

> GoldLottery deployed at: 0xD89f1BEdcf1a95e86406A1A61987F3D2968d99e2
> GoldToken deployed at: 0x19893058896A4898442a9aad1413df56E3092a92

> Send some ETH to the tokencontract

cast send 0x19893058896A4898442a9aad1413df56E3092a92 \
    --value 0.01ether \
    --private-key $PRIVATE_KEY \
    --rpc-url $RPC_URL

> Check goldToken contract's balance :

cast balance 0x19893058896A4898442a9aad1413df56E3092a92 --rpc-url $RPC_URL

<!-- > Check lottery contract's balance :

cast call 0x19893058896A4898442a9aad1413df56E3092a92 \
    "lotteryBalance()(uint256)" \
    --rpc-url $RPC_URL -->

> Check participants in the lottery : 

cast call 0x18715183248AAef4687DEC37fBF792C1412b3b0B "getParticipants()" --rpc-url $RPC_URL

> Check his % of chances :

cast call 0x18715183248AAef4687DEC37fBF792C1412b3b0B \
    "getChances(address)(uint256)" \
    0xF389635f844DaA5051aF879a00077C6C9F2aA345 \
    --rpc-url $RPC_URL
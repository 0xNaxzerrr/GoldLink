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
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


== Logs ==
  Sepolia - GoldLottery deployed at: 0xbD3D66AE432d0F8C985E1791cD3b92403F35ebCc
  Sepolia - GoldToken deployed at: 0x807c16099D12DD9f6e61103cB8D0e77306B002C2
  Sepolia - GoldBridge deployed at: 0xe087E8938fD8e1904b777d1Bb54E19928cE16CED

== Logs ==
  BSC - GoldTokenBSC deployed at: 0xa6DdB39862E7175521a3711DC86807c9501C5512
  BSC - GoldBridgeBSC deployed at: 0xB1081244C17317163Bed920665e54b3D017f92C8

## Setting up 1 EVM.

==========================

Chain 11155111

Estimated gas price: 11.993078839 gwei

Estimated total gas used for script: 12728790

Estimated amount required: 0.15265738199507481 ETH

==========================
                                                                                                                                                 
Transactions saved to: C:/Users/julie/Bureau/5ème-année/solidity/GoldLink\broadcast\DeployGoldToken.s.s==========================

Transactions saved to: C:/Users/julie/Bureau/5ème-année/solidity/GoldLink\broadcast\DeployGoldToken.s.sol\11155111\run-latest.json

Sensitive values saved to: C:/Users/julie/Bureau/5ème-année/solidity/GoldLink/cache\DeployGoldToken.s.sol\11155111\run-latest.json

====  TEST =======

julie@Julien MINGW64 ~/Bureau/5ème-année/solidity/GoldLink (main)
$ cast send 0x8296a1B87c499b3bd8163Eef57a60Faa1bb4A8a4 "mint()" --value 0.1ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL

blockHash               0xad4f22e05c9df21f2eba32cd035f2cbf723ee8b26f9117d4bf28d32b73ac1932
blockNumber             7263856
contractAddress
cumulativeGasUsed       12256538
effectiveGasPrice       4865796495
from                    0x6c9622A0472681f150773108C0A8662A0528c6Ef
gasUsed                 253905
logs                    [{"address":"0x2b1be89b1ead9faecc6b35044b7cd18fe06319b8","topics":["0xc28711c8dcc0cb3d25732e13809d1d8c2640669a0a3fb4f7729810a9caaffdff","0x0000000000000000000000006c9622a0472681f150773108c0a8662a0528c6ef"],"data":"0x0000000000000000000000000000000000000000000000052663ccab1e1c0000","blockHash":"0xad4f22e05c9df21f2eba32cd035f2cbf723ee8b26f9117d4bf28d32b73ac1932","blockNumber":"0x6ed670","transactionHash":"0xf9a04f06696b177595c216fb690ef56ec8fee006c7e0ec01d230fac889068b97","transactionIndex":"0x93","logIndex":"0xd8","removed":false},{"address":"0xbd0316d3c0e465273f1eb53d5d9c78803b7ac16d","topics":["0x63373d1c4696214b898952999c9aaec57dac1ee2723cec59bea6888f489a9772","0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae","0x0000000000000000000000000000000000000000000000000000000000000001","0x0000000000000000000000002b1be89b1ead9faecc6b35044b7cd18fe06319b8"],"data":"0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000186a00000000000000000000000000000000000000000000000000000000000000001","blockHash":"0xad4f22e05c9df21f2eba32cd035f2cbf723ee8b26f9117d4bf28d32b73ac1932","blockNumber":"0x6ed670","transactionHash":"0xf9a04f06696b177595c216fb690ef56ec8fee006c7e0ec01d230fac889068b97","transactionIndex":"0x93","logIndex":"0xd9","removed":false},{"address":"0x2b1be89b1ead9faecc6b35044b7cd18fe06319b8","topics":["0xcc58b13ad3eab50626c6a6300b1d139cd6ebb1688a7cced9461c2f7e762665ee"],"data":"0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001","blockHash":"0xad4f22e05c9df21f2eba32cd035f2cbf723ee8b26f9117d4bf28d32b73ac1932","blockNumber":"0x6ed670","transactionHash":"0xf9a04f06696b177595c216fb690ef56ec8fee006c7e0ec01d230fac889068b97","transactionIndex":"0x93","logIndex":"0xda","removed":false},{"address":"0x8296a1b87c499b3bd8163eef57a60faa1bb4a8a4","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x0000000000000000000000000000000000000000000000000000000000000000","0x0000000000000000000000006c9622a0472681f150773108c0a8662a0528c6ef"],"data":"0x0000000000000000000000000000000000000000000000052663ccab1e1c0000","blockHash":"0xad4f22e05c9df21f2eba32cd035f2cbf723ee8b26f9117d4bf28d32b73ac1932","blockNumber":"0x6ed670","transactionHash":"0xf9a04f06696b177595c216fb690ef56ec8fee006c7e0ec01d230fac889068b97","transactionIndex":"0x93","logIndex":"0xdb","removed":false},{"address":"0x8296a1b87c499b3bd8163eef57a60faa1bb4a8a4","topics":["0x2e8ac5177a616f2aec08c3048f5021e4e9743ece034e8d83ba5caf76688bb475","0x0000000000000000000000006c9622a0472681f150773108c0a8662a0528c6ef"],"data":"0x0000000000000000000000000000000000000000000000052663ccab1e1c00000000000000000000000000000000000000000000000000004563918244f40000","blockHash":"0xad4f22e05c9df21f2eba32cd035f2cbf723ee8b26f9117d4bf28d32b73ac1932","blockNumber":"0x6ed670","transactionHash":"0xf9a04f06696b177595c216fb690ef56ec8fee006c7e0ec01d230fac889068b97","transactionIndex":"0x93","logIndex":"0xdc","removed":false}]
logsBloom               0x0211000000000000000000000000000000000000000008000004000000000000000001000000200000000000000000000000000100000000000010800004000000800000000000000002000800000000000000000004000000200200000000002000000002000000000000000040080000000000000000000000001000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000008000800000020000000000000800000000000000000000000000200000000010000000000c000000000000000000000002000000060000008000000002000000100000000000000000000000000000000400000080000
root                    
status                  1 (success)
transactionHash         0xf9a04f06696b177595c216fb690ef56ec8fee006c7e0ec01d230fac889068b97
transactionIndex        147
type                    2
blobGasPrice
blobGasUsed
authorizationList
to                      0x8296a1B87c499b3bd8163Eef57a60Faa1bb4A8a4

julie@Julien MINGW64 ~/Bureau/5ème-année/solidity/GoldLink (main)
$ cast send 0x2B1Be89b1eAD9Faecc6B35044b7Cd18Fe06319B8 "depositFees(uint256)" 1000000000000000000 --value 1ether --private-key $PRIVATE_KEY --rpc-url $RPC_URL

blockHash               0x857d12cd65d510677e11920a5d520cb86b2f1038f511c37987f97594f310b271
blockNumber             7263858
contractAddress
cumulativeGasUsed       14706304
effectiveGasPrice       4819185425
from                    0x6c9622A0472681f150773108C0A8662A0528c6Ef
gasUsed                 26918
logs                    []
logsBloom               0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
root
status                  1 (success)
transactionHash         0xcd5b54ef772c86c434cbf212ae55929943577370416a197abc6ac2d18b769dc0
transactionIndex        177
type                    2
blobGasPrice
blobGasUsed
authorizationList
to                      0x2B1Be89b1eAD9Faecc6B35044b7Cd18Fe06319B8

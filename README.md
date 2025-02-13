# GoldLink - Bridge Cross-chain avec Chainlink CCIP

Un système de bridge cross-chain permettant de transférer des tokens entre Sepolia et BSC Testnet utilisant Chainlink CCIP.

## Prérequis

```bash
# Variables d'environnement nécessaires (.env)
PRIVATE_KEY=<votre_clé_privée>
RPC_URL_SEPOLIA=<url_rpc_sepolia>
RPC_URL_BSC_TESTNET=<url_rpc_bsc_testnet>
ETHERSCAN_API_KEY=<votre_clé_api>
BSCSCAN_API_KEY=<votre_clé_api_bsc>
```

## Déploiement des Contrats

### 1. Déploiement sur Sepolia

```bash
forge script script/DeploySepoliaContracts.s.sol:DeploySepoliaContracts \
    --rpc-url $RPC_URL_SEPOLIA \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

### 2. Déploiement sur BSC Testnet

```bash
forge script script/DeployBSCContracts.s.sol:DeployBSCContracts \
    --rpc-url $RPC_URL_BSC_TESTNET \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $BSCSCAN_API_KEY
```

## Configuration des Bridges

### 1. Configuration du Bridge BSC

```bash
# 1.1 Configurer l'adresse source autorisée
cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY \
    $GOLD_BRIDGE_BSC \
    "setAuthorizedSourceAddress(address)" \
    $GOLD_BRIDGE_SEPOLIA

# 1.2 Configurer le contrat distant
cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY \
    $GOLD_BRIDGE_BSC \
    "setRemoteContract(bytes)" \
    $(cast abi-encode "f(address)" $GOLD_BRIDGE_SEPOLIA)

# 1.3 Configurer le chain selector de Sepolia
cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY \
    $GOLD_BRIDGE_BSC \
    "setSepoliaChainId(uint64)" \
    16015286601757825753
```

### 2. Configuration du Bridge Sepolia

```bash
# 2.1 Configurer le contrat distant
cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY \
    $GOLD_BRIDGE_SEPOLIA \
    "setRemoteContract(bytes)" \
    $(cast abi-encode "f(address)" $GOLD_BRIDGE_BSC)

# 2.2 Configurer le chain selector de BSC
cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY \
    $GOLD_BRIDGE_SEPOLIA \
    "setDestinationChainId(uint64)" \
    13264668187771770619
```

## Vérification de la Configuration

```bash
# Vérifier la configuration BSC
cast call $GOLD_BRIDGE_BSC "remoteContractOnSepoliaChain()(bytes)" --rpc-url $RPC_URL_BSC_TESTNET
cast call $GOLD_BRIDGE_BSC "authorizedSourceAddress()(address)" --rpc-url $RPC_URL_BSC_TESTNET
cast call $GOLD_BRIDGE_BSC "sepoliaChainId()(uint64)" --rpc-url $RPC_URL_BSC_TESTNET

# Vérifier la configuration Sepolia
cast call $GOLD_BRIDGE_SEPOLIA "remoteContractOnDestinationChain()(bytes)" --rpc-url $RPC_URL_SEPOLIA
cast call $GOLD_BRIDGE_SEPOLIA "destinationChainId()(uint64)" --rpc-url $RPC_URL_SEPOLIA
```

## Utilisation du Bridge

### Bridge Sepolia → BSC

```bash
# Transférer 1 GOLD token de Sepolia vers BSC
cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY \
    $GOLD_BRIDGE_SEPOLIA \
    "bridgeOut(address,uint256)" \
    <ADRESSE_RECIPIENT> \
    1000000000000000000
```

### Bridge BSC → Sepolia

```bash
# Transférer 1 GOLD token de BSC vers Sepolia
cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY \
    $GOLD_BRIDGE_BSC \
    "bridgeBack(address,uint256)" \
    <ADRESSE_RECIPIENT> \
    1000000000000000000
```

## Vérification des Soldes

```bash
# Vérifier le solde GOLD sur Sepolia
cast call $GOLD_TOKEN_SEPOLIA "balanceOf(address)(uint256)" <ADRESSE> --rpc-url $RPC_URL_SEPOLIA

# Vérifier le solde GOLD sur BSC
cast call $GOLD_TOKEN_BSC "balanceOf(address)(uint256)" <ADRESSE> --rpc-url $RPC_URL_BSC_TESTNET
```

## Architecture

- **GoldToken (Sepolia)**: Token ERC20 avec mint basé sur le prix de l'or
- **GoldTokenBSC**: Version BSC du token
- **GoldBridge**: Bridge côté Sepolia qui gère les transferts vers BSC
- **GoldBridgeBSC**: Bridge côté BSC qui gère les transferts vers Sepolia
- **Chainlink CCIP**: Utilisé pour la communication cross-chain sécurisée

## Notes Importantes

1. Assurez-vous d'avoir suffisamment de LINK sur les deux réseaux
2. Les transactions prennent généralement 2-3 minutes
3. Les bridges utilisent le pattern UUPS pour les mises à niveau
4. Les adresses sources sont vérifiées pour la sécurité

    pense bete : 
    BSC
    cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY $GOLD_BRIDGE_BSC        "setAuthorizedSourceAddress(address)" $GOLD_BRIDGE_SEPOLIA

    cast send --rpc-url $RPC_URL_BSC_TESTNET --private-key $PRIVATE_KEY \
        $GOLD_BRIDGE_BSC \
        "setRemoteContract(bytes)" \
        $(cast abi-encode "f(address)" $GOLD_BRIDGE_SEPOLIA)

    SEPOLIA
        cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY \
        $GOLD_BRIDGE_SEPOLIA \
        "setRemoteContract(bytes)" \
        $(cast abi-encode "f(address)" $GOLD_BRIDGE_BSC)
        


   ===================     BridgeOut : ================

    MESSAGE ID : 0x1cf2832e5ce63995d8f6c2c6253bfe95a2b8893105788054e0eca60545ff1636
    TX : [0x3940395f4930748267f1733d8e80d5c78b5a670c6244ea9038f98f8000802e78](https://ccip.chain.link/#/side-drawer/msg/0x9b3f782af56b1e3a5aa2d4b6b8785d980535ff6a36b8a99fc95d828f1aa606ac)


       ===================     BridgeBack : ================

    MESSAGE ID : 0xf12914357ac2106342184f4b767df04037e4c7b9d57a5c101510e319b39252ca
    TX : [0xdc6a3a5450949df7b0c64b429aabc6fe066ecaf98672f0d0e7d2bb0e73c10be6](https://testnet.bscscan.com/tx/0x58b46441ab348d7f199abe949ac24bb7f4b7a0613fc335eb640be24ead706a4b)
== Logs ==
  Created VRF subscription: 71713578663295574710251398792567627846667888060653069655504016799701196913728
  Funded subscription with 2 LINK
  Added Lottery as VRF consumer
  Deployed Lottery at: 0x324e3ec37929f028aC17be0C34de1250D8704807
  VRF Subscription ID: 71713578663295574710251398792567627846667888060653069655504016799701196913728

== Logs ==
  Initial tokens minted successfully
  Deployed on Sepolia:
  Token: 0x31cfae161560627e971Ba264382d0Dcf0c5D57eD
  GoldBridge: 0xB976A047d32C711147D9529388F60B1A4b5CA5aE
  Proxy: 0xDd9ca6C3665219fe71d3847CE8d5742d6ca84a02
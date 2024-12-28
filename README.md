# GoldLink Project

**GoldLink** est un projet inter-chaînes qui permet de transférer des tokens entre Sepolia et Binance Smart Chain (BSC Testnet) en utilisant Chainlink CCIP. A chaque mint du token Gold, l'user est intégré automatiquement a une lottery (VRF Chainlink), dès que le montant fixé est atteint, un user se voit remporter une somme !

## Table des matières
1. [Description](#description)
2. [Déploiement des Contrats](#déploiement-des-contrats)
3. [Configuration des Contrats](#configuration-des-contrats)
4. [Exécution du Bridge](#exécution-du-bridge)
5. [Étapes Complètes](#étapes-complètes)
6. [Informations Techniques](#informations-techniques)

---

## Description

Le projet déploie et configure un système de bridge permettant le transfert de tokens entre deux blockchains :

- **Sepolia (Ethereum Testnet)**
- **BSC Testnet (Binance Smart Chain)**

Les principaux composants du projet incluent :

- **GoldToken** : Un token ERC-20 sur Sepolia.
- **GoldTokenBSC** : Un token équivalent sur BSC Testnet.
- **GoldLink** : Un bridge inter-chaînes sur Sepolia.
- **GoldLinkBSC** : Un bridge inter-chaînes sur BSC Testnet.

---

## Déploiement des Contrats

### Sur Sepolia
Commandes pour déployer les contrats sur Sepolia :

```bash
forge script script/DeploySepoliaContracts.s.sol --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

**Contrats déployés :**
- **GoldLottery** : `0x2F5B9354f74dA9f8743B76eb04527746b595942B`
- **GoldToken** : `0x25B1DD9F93ed037226f8C130f44Ed53880E75f8F`
- **GoldBridge** : `0xB4E59e35Fb2249159AC289AFa89723c9Aa9DB076`

---

### Sur BSC Testnet
Commandes pour déployer les contrats sur BSC Testnet :
```bash
forge script script/DeployBSCContracts.s.sol --rpc-url https://bsc-testnet-rpc.publicnode.com --broadcast --private-key $PRIVATE_KEY --gas-price 70000000000
```


**Contrats déployés :**
- **GoldTokenBSC** : `0xa360ecF90b6d94Edee7B1cA9447421A4F98b59A3`
- **GoldBridgeBSC** : `0x167BfE5e259982774B5873E207dd76683c9981Ac`

---

## Configuration des Contrats

### 1. Configurez le contrat distant pour Sepolia :
```bash
cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY
0xB4E59e35Fb2249159AC289AFa89723c9Aa9DB076
"setRemoteContract(bytes)"
$(cast abi-encode "f(address)" 0x167BfE5e259982774B5873E207dd76683c9981Ac)
```

### 2. Configurez l'ID de la chaîne Sepolia sur BSC :

```bash
cast send --rpc-url $RPC_URL_BNB --private-key $PRIVATE_KEY
0x167BfE5e259982774B5873E207dd76683c9981Ac
"setSepoliaChainId(uint64)" 11155111
```

### 3. Configurez l'ID de la chaîne BSC sur Sepolia :

```bash
cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY
0xB4E59e35Fb2249159AC289AFa89723c9Aa9DB076
"setDestinationChainId(uint64)" 13264668187771770619
```

### 4. Configurez l'adresse autorisée sur BSC :

```bash
cast send --rpc-url $RPC_URL_BNB --private-key $PRIVATE_KEY
0x167BfE5e259982774B5873E207dd76683c9981Ac
"setAuthorizedSourceAddress(address)"
0xB4E59e35Fb2249159AC289AFa89723c9Aa9DB076
```

### 5. Ajoutez des fonds pour couvrir les frais CCIP :
Sur **Sepolia** :

```bash
cast send --rpc-url $RPC_URL_SEPOLIA --private-key $PRIVATE_KEY
0xB4E59e35Fb2249159AC289AFa89723c9Aa9DB076
--value 0.1ether
```

Sur **BSC** :
```bash
cast send --rpc-url $RPC_URL_BNB --private-key $PRIVATE_KEY
0x167BfE5e259982774B5873E207dd76683c9981Ac
--value 0.1ether
```

---

## Exécution du Bridge

### Étape 1 : Approuvez les tokens
Sur **Sepolia** :
```bash
cast send 0x25B1DD9F93ed037226f8C130f44Ed53880E75f8F
"approve(address,uint256)"
0xB4E59e35Fb2249159AC289AFa89723c9Aa9DB076 10000000000000000
--rpc-url $RPC_URL_SEPOLIA
--private-key $PRIVATE_KEY
```

### Étape 2 : Initiez le transfert inter-chaînes
Sur **Sepolia** :
```bash
cast send 0xB4E59e35Fb2249159AC289AFa89723c9Aa9DB076
"bridgeOut(address,uint256)"
0xF389635f844DaA5051aF879a00077C6C9F2aA345 10000000000000000
--rpc-url $RPC_URL_SEPOLIA
--private-key $PRIVATE_KEY
```

---

## Étapes Complètes

1. Déployez les contrats sur Sepolia et BSC Testnet.
2. Configurez les contrats pour interagir entre eux.
3. Ajoutez des fonds pour couvrir les frais CCIP.
4. Approuvez les tokens GoldToken/GoldTokenBSC pour les bridges.
5. Exécutez la fonction `bridgeOut` pour transférer les tokens.

---

## Informations Techniques

### Adresse des Contrats

| Réseau         | Contrat         | Adresse                                    |
|----------------|-----------------|--------------------------------------------|
| Sepolia        | GoldToken       | 0x25B1DD9F93ed037226f8C130f44Ed53880E75f8F |
| Sepolia        | GoldBridge      | 0xB4E59e35Fb2249159AC289AFa89723c9Aa9DB076 |
| BSC Testnet    | GoldTokenBSC    | 0xa360ecF90b6d94Edee7B1cA9447421A4F98b59A3 |
| BSC Testnet    | GoldBridgeBSC   | 0x167BfE5e259982774B5873E207dd76683c9981Ac |

---

**Transaction Hash :**
Transaction réussie pour `bridgeOut` : `0x25170C522FB7D4C840869758F78855ED967E7EEB8794AF85E0750F2E2BF9701F`

---

## Remarques
- Assurez-vous que vos contrats contiennent suffisamment de fonds pour couvrir les frais CCIP.
- Vérifiez les configurations (contract addresses, chain IDs) avant d'exécuter les commandes.

--- 
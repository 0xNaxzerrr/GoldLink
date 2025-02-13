// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IGoldToken.sol";
import "../interfaces/IGoldLottery.sol";
import "forge-std/console2.sol";

/**
 * @title GoldToken
 * @notice ERC20 token indexé sur le prix de l'or avec fonctionnalités de bridge et upgrade via UUPS.
 * @dev Implémente des feeds de prix Chainlink pour XAU/USD et ETH/USD, et intègre des mécanismes de mint, burn et bridging.
 */
contract GoldToken is IGoldToken, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {

    /// @notice Feed de prix XAU/USD fourni par Chainlink.
    AggregatorV3Interface public immutable xauUsdFeed;
    
    /// @notice Feed de prix ETH/USD fourni par Chainlink.
    AggregatorV3Interface public immutable ethUsdFeed;
    
    /// @notice Adresse du contrat de loterie (utilisé pour collecter les frais).
    address payable public immutable goldLottery;
    
    /// @notice Adresse du contrat bridge pour les transferts cross-chain.
    address public bridgeAddress;

    /// @notice Pourcentage de frais appliqué lors des opérations de mint/burn (5%).
    uint256 public constant FEE_PERCENTAGE = 5;
    
    /// @dev Période de staleness pour les feeds (non utilisé dans ce contrat, mais défini pour référence).
    uint256 private constant STALENESS_PERIOD = 1 hours;

    /// @notice Conversion d'une once troy en grammes (valeur fixe).
    uint256 public constant TROY_OUNCE_IN_GRAMS = 31_103_476_800;

    /**
     * @notice Constructeur du contrat.
     * @dev Initialise les feeds de prix et l'adresse du contrat de loterie. 
     * @param _xauUsdFeed Adresse du feed XAU/USD.
     * @param _ethUsdFeed Adresse du feed ETH/USD.
     * @param _goldLottery Adresse du contrat de loterie.
     *
     * Requirements:
     * - Aucun des paramètres ne doit être l'adresse zéro.
     *
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(
        address _xauUsdFeed,
        address _ethUsdFeed,
        address payable _goldLottery
    ) {
        if (_xauUsdFeed == address(0) || _ethUsdFeed == address(0) || _goldLottery == address(0)) 
            revert InvalidValue();
        xauUsdFeed = AggregatorV3Interface(_xauUsdFeed);
        ethUsdFeed = AggregatorV3Interface(_ethUsdFeed);
        goldLottery = _goldLottery;
    }

    /**
     * @notice Initialise le contrat upgradeable.
     * @dev Doit être appelée une seule fois par le proxy pour initialiser le token.
     * Initialise le nom et le symbole du token.
     */
    function initialize() external initializer {
        __ERC20_init("GoldToken", "GOLD");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Permet de mint des tokens en envoyant de l'ETH.
     * @dev Calcule le nombre de tokens à mint en fonction du prix de l'or et des ETH envoyés.
     * Les frais prélevés sont déposés dans le contrat de loterie, qui gère également l'entrée dans la loterie.
     *
     * Requirements:
     * - Le montant envoyé en ETH (`msg.value`) doit être supérieur à zéro.
     * - Les feeds de prix doivent renvoyer des valeurs valides.
     *
     * Emits a {TokensMinted} event.
     */
    function mint() external payable {
        require(msg.value > 0, "Must send ETH");

        (, int256 xauUsdPrice, , , ) = xauUsdFeed.latestRoundData();
        (, int256 ethUsdPrice, , , ) = ethUsdFeed.latestRoundData();
        require(xauUsdPrice > 0 && ethUsdPrice > 0, "Invalid feeds");

        uint256 xauUsd = uint256(xauUsdPrice); 
        uint256 ethUsd = uint256(ethUsdPrice); 

        // Calcule le prix de 1 gramme d'or en USD (ajusté pour la précision).
        uint256 gramGoldUsd = (xauUsd * 1e8) / TROY_OUNCE_IN_GRAMS;

        // Calcule le coût en ETH pour 1 gramme d'or.
        uint256 gramGoldEth = (gramGoldUsd * 1e19) / ethUsd;
        require(gramGoldEth > 0, "Invalid ratio");

        // Calcule la quantité de tokens à mint en fonction de l'ETH envoyé.
        uint256 goldAmount = (msg.value * 1e18) / gramGoldEth;

        // Applique les frais de 5%.
        uint256 feeTokens = (goldAmount * FEE_PERCENTAGE) / 100;
        uint256 mintAmount = goldAmount - feeTokens;

        // Calcule le montant en ETH correspondant aux frais.
        uint256 feeWei = (msg.value * feeTokens) / goldAmount;
        require(feeWei < msg.value, "Fee too high");

        // Dépose les frais dans le contrat de loterie et inscrit l'utilisateur dans la loterie.
        IGoldLottery(goldLottery).depositFees{value: feeWei}(feeWei);
        IGoldLottery(goldLottery).enterLottery(msg.sender, mintAmount);

        // Mint les tokens à l'utilisateur.
        _mint(msg.sender, mintAmount);

        emit TokensMinted(msg.sender, mintAmount, feeTokens);
    }

    /**
     * @notice Permet de brûler des tokens et de récupérer de l'ETH.
     * @dev Calcule la quantité d'ETH à renvoyer en fonction du montant de tokens brûlés et du prix de l'or.
     *
     * @param amount Quantité de tokens à brûler.
     *
     * Requirements:
     * - L'utilisateur doit disposer d'un solde suffisant en tokens.
     * - Les feeds de prix doivent renvoyer des valeurs valides.
     *
     * Emits a {TokensBurned} event.
     */
    function burn(uint256 amount) external override {
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();

        (, int256 xauUsdPrice, , , ) = xauUsdFeed.latestRoundData();
        (, int256 ethUsdPrice, , , ) = ethUsdFeed.latestRoundData();
        if (xauUsdPrice <= 0 || ethUsdPrice <= 0) revert InvalidFeeds();

        uint256 xauUsd = uint256(xauUsdPrice);
        uint256 ethUsd = uint256(ethUsdPrice);

        uint256 gramGoldUsd = (xauUsd * 1e8) / TROY_OUNCE_IN_GRAMS;
        uint256 gramGoldEth = (gramGoldUsd * 1e18) / ethUsd;
        if (gramGoldEth == 0) revert InvalidValue();

        // Calcule la quantité d'ETH à retourner pour le montant de tokens brûlés.
        uint256 ethAmount = (amount * gramGoldEth) / 1e18;

        // Calcule et déduit les frais.
        uint256 feeTokens = (amount * FEE_PERCENTAGE) / 100;
        uint256 feeWei = (feeTokens * ethAmount) / amount;
        uint256 burnWei = ethAmount - feeWei;

        // Brûle les tokens de l'utilisateur.
        _burn(msg.sender, amount);

        // Dépose les frais dans le contrat de loterie.
        IGoldLottery(goldLottery).depositFees{value: feeWei}(feeWei);

        // Transfère l'ETH restant à l'utilisateur.
        payable(msg.sender).transfer(burnWei);
        emit TokensBurned(msg.sender, amount, feeTokens);
    }

    /**
     * @notice Brûle des tokens depuis une adresse approuvée.
     * @param account Adresse depuis laquelle les tokens seront brûlés.
     * @param amount Quantité de tokens à brûler.
     *
     * Requirements:
     * - L'appelant doit avoir une autorisation suffisante pour brûler les tokens de `account`.
     */
    function burnFrom(address account, uint256 amount) external override {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    /**
     * @notice Permet au propriétaire de mint des tokens.
     * @param to Adresse du destinataire.
     * @param amount Quantité de tokens à mint.
     *
     * Requirements:
     * - Seul le propriétaire peut appeler cette fonction.
     */
    function adminMint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Définit l'adresse du contrat bridge.
     * @param _bridge Nouvelle adresse du contrat bridge.
     *
     * Requirements:
     * - L'adresse `_bridge` ne doit pas être l'adresse zéro.
     */
    function setBridgeAddress(address _bridge) external override onlyOwner {
        if (_bridge == address(0)) revert InvalidValue();
        bridgeAddress = _bridge;
    }

    /**
     * @notice Mint des tokens à partir du contrat bridge.
     * @param to Adresse du destinataire.
     * @param amount Quantité de tokens à mint.
     *
     * Requirements:
     * - Seul le contrat bridge (défini dans `bridgeAddress`) peut appeler cette fonction.
     */
    function bridgeMint(address to, uint256 amount) external override {
        if (msg.sender != bridgeAddress) revert UnauthorizedBridge();
        _mint(to, amount);
    }

    /**
     * @notice Autorise une mise à niveau du contrat vers une nouvelle implémentation.
     * @dev Seul le propriétaire peut autoriser une mise à niveau.
     * @param newImplementation Adresse du nouveau contrat d'implémentation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

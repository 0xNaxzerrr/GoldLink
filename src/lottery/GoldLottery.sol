// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IGoldLottery.sol";

/**
 * @title GoldLottery
 * @notice Contrat de loterie qui permet aux participants d'entrer dans une loterie en déposant des tokens.
 * @dev Utilise Chainlink VRF V2 Plus pour obtenir un nombre aléatoire et sélectionner un gagnant.
 *      Le contrat est upgradeable via le pattern UUPS et hérite d'OwnableUpgradeable.
 */
contract GoldLottery is IGoldLottery, OwnableUpgradeable, UUPSUpgradeable {
    /// @notice Instance du coordinateur VRF de Chainlink
    IVRFCoordinatorV2Plus private immutable vrfCoordinator;
    
    /// @notice Clé utilisée pour la demande de nombre aléatoire
    bytes32 private immutable KEY_HASH;    
    
    /// @notice Identifiant de la souscription pour Chainlink VRF
    uint256 private immutable SUBSCRIPTION_ID;
    
    /// @notice Limite de gas pour l'exécution du callback VRF
    uint32 private immutable CALLBACK_GAS_LIMIT;
    
    /// @notice Nombre de confirmations minimales pour la demande VRF
    uint16 private immutable REQUEST_CONFIRMATIONS;
    
    /// @notice Nombre de mots aléatoires demandés (fixé à 1)
    uint32 private constant NUM_WORDS = 1;
    
    /// @notice Indique si le paiement natif est activé (fixé à true)
    bool private constant NATIVE_PAYMENT = true;

    /**
     * @notice Structure pour suivre l'état d'une demande de nombre aléatoire.
     * @param fulfilled Indique si la demande a été satisfaite.
     * @param exists Indique si la demande existe.
     * @param randomWords Tableau contenant les nombres aléatoires retournés.
     */
    struct RequestStatus {
        bool fulfilled;
        bool exists;
        uint256[] randomWords;
    }

    /// @notice Total des tokens déposés pour la loterie (entrées cumulées)
    uint256 public tokensMinted;
    
    /// @notice Solde total des fonds de la loterie
    uint256 public lotteryBalance;
    
    /// @notice Adresse du dernier gagnant de la loterie
    address public lastWinner;
    
    /// @notice Montant versé lors du dernier gain
    uint256 public lastPayout;
    
    /// @notice Liste des participants dans la loterie
    address[] private participants;
    
    /// @notice Mapping des chances attribuées à chaque participant
    mapping(address => uint256) private chances;
    
    /// @notice Mapping des statuts des demandes VRF, indexé par requestId
    mapping(uint256 => RequestStatus) private s_requests;

    /**
     * @notice Constructeur du contrat.
     * @dev Vérifie que les paramètres fournis respectent certaines conditions.
     * @param _vrfCoordinator Adresse du coordinateur VRF de Chainlink.
     * @param _keyHash Clé utilisée pour la demande de nombre aléatoire.
     * @param _subscriptionId Identifiant de la souscription Chainlink VRF.
     * @param _callbackGasLimit Limite de gas pour l'exécution du callback VRF.
     * @param _requestConfirmations Nombre de confirmations minimales pour la demande VRF.
     *
     * Requirements:
     * - `_callbackGasLimit` doit être au moins 100000.
     * - `_requestConfirmations` doit être au moins 3.
     */
    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) {
        require(_callbackGasLimit >= 100000, "Callback gas limit too low");
        require(_requestConfirmations >= 3, "Min confirmations not met");
        
        vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
        KEY_HASH = _keyHash;
        SUBSCRIPTION_ID = _subscriptionId;
        CALLBACK_GAS_LIMIT = _callbackGasLimit;
        REQUEST_CONFIRMATIONS = _requestConfirmations;
    }

    /**
     * @notice Initialise le contrat upgradeable.
     * @dev Doit être appelé une seule fois après le déploiement.
     */
    function initialize() external override initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /**
     * @notice Permet à un participant d'entrer dans la loterie.
     * @dev Le participant se voit attribuer des "chances" proportionnelles au montant déposé.
     * @param participant Adresse du participant.
     * @param amount Quantité de tokens entrant dans le calcul des chances.
     *
     * Requirements:
     * - `participant` ne doit pas être l'adresse zéro.
     * - `amount` doit être supérieur à zéro.
     *
     * Emits a {LotteryEntered} event.
     */
    function enterLottery(address participant, uint256 amount) external override {
        if (participant == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        tokensMinted += amount;
        if (chances[participant] == 0) participants.push(participant);
        chances[participant] += amount;

        emit LotteryEntered(participant, amount);
    }

    /**
     * @notice Permet de déposer des frais dans le contrat de loterie.
     * @dev Le montant envoyé en Ether doit correspondre à `amount`.
     * @param amount Montant des frais à déposer (en wei).
     *
     * Requirements:
     * - `msg.value` doit être égal à `amount`.
     *
     * Emits a {FeesDeposited} event (si défini dans l'interface).
     */
    function depositFees(uint256 amount) external payable override {
        if (msg.value != amount) revert InvalidAmount();
        lotteryBalance += amount;
    }

    /**
     * @notice Lance le processus de tirage au sort de la loterie.
     * @dev Seul le propriétaire peut appeler cette fonction.
     * @return requestId Identifiant de la demande VRF.
     *
     * Requirements:
     * - Il doit y avoir au moins un participant.
     * - Le solde de la loterie doit être supérieur à zéro.
     *
     * Emits a {RequestSent} event.
     */
    function drawLottery() external override onlyOwner returns (uint256) {
        return _drawLottery();
    }

    /**
     * @notice Fonction privée qui initie une demande de nombre aléatoire via Chainlink VRF.
     * @dev Enregistre l'état de la demande et émet un événement.
     * @return requestId Identifiant de la demande VRF.
     *
     * Requirements:
     * - Il doit y avoir des participants.
     * - Le solde de la loterie ne doit pas être nul.
     */
    function _drawLottery() private returns (uint256 requestId) {
        if (participants.length == 0) revert NoParticipants();
        if (lotteryBalance == 0) revert NoBalance();

        requestId = vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: KEY_HASH,
                subId: SUBSCRIPTION_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: NATIVE_PAYMENT})
                )
            })
        );

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](NUM_WORDS),
            exists: true,
            fulfilled: false
        });

        emit RequestSent(requestId, NUM_WORDS);
        return requestId;
    }

    /**
     * @notice Fonction appelée par le coordinateur VRF pour fournir les nombres aléatoires.
     * @dev Seul le coordinateur VRF est autorisé à appeler cette fonction.
     * @param requestId Identifiant de la demande VRF.
     * @param randomWords Tableau contenant les nombres aléatoires.
     *
     * Requirements:
     * - L'appelant doit être le coordinateur VRF.
     */
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        require(msg.sender == address(vrfCoordinator), "Only VRFCoordinator");
        fulfillRandomWords(requestId, randomWords);
    }

    /**
     * @notice Traite les nombres aléatoires retournés par Chainlink VRF.
     * @dev Vérifie que la demande existe et n'a pas déjà été satisfaite.
     *      Sélectionne un gagnant, distribue le prix et réinitialise la loterie.
     * @param requestId Identifiant de la demande VRF.
     * @param randomWords Tableau contenant les nombres aléatoires.
     *
     * Requirements:
     * - La demande doit exister et ne pas être déjà satisfaite.
     *
     * Emits a {LotteryWinner} event et {RequestFulfilled} event.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual {
        if (!s_requests[requestId].exists) revert RequestNotExists();
        if (s_requests[requestId].fulfilled) revert RequestAlreadyFulfilled();

        address winner = _selectWinner(randomWords[0]);
        _distributePrize(winner);
        _resetLottery(requestId, randomWords);
    }

    /**
     * @notice Sélectionne un gagnant de la loterie en fonction d'un nombre aléatoire.
     * @dev Le gagnant est déterminé proportionnellement aux chances accumulées.
     * @param randomWord Un nombre aléatoire fourni par VRF.
     * @return L'adresse du gagnant sélectionné.
     */
    function _selectWinner(uint256 randomWord) private view returns (address) {
        uint256 totalChances = _calculateTotalChances();
        uint256 randomChance = randomWord % totalChances;
        uint256 cumulativeChances = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            cumulativeChances += chances[participants[i]];
            if (randomChance < cumulativeChances) {
                return participants[i];
            }
        }
        return participants[participants.length - 1];
    }

    /**
     * @notice Calcule le total des chances accumulées par tous les participants.
     * @return Le total des chances.
     */
    function _calculateTotalChances() private view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < participants.length; i++) {
            total += chances[participants[i]];
        }
        return total;
    }

    /**
     * @notice Distribue le prix de la loterie au gagnant.
     * @dev Transfère la totalité du solde de la loterie au gagnant et émet un événement.
     * @param winner Adresse du gagnant.
     *
     * Emits a {LotteryWinner} event.
     */
    function _distributePrize(address winner) private {
        uint256 prize = lotteryBalance;
        lotteryBalance = 0;
        lastWinner = winner;
        lastPayout = prize;
        
        (bool success, ) = winner.call{value: prize}("");
        if (!success) revert();
        
        emit LotteryWinner(winner, prize);
    }

    /**
     * @notice Réinitialise la loterie après le tirage.
     * @dev Marque la demande comme satisfaite, réinitialise les chances des participants et vide la liste.
     * @param requestId Identifiant de la demande VRF.
     * @param randomWords Tableau contenant les nombres aléatoires.
     *
     * Emits a {RequestFulfilled} event.
     */
    function _resetLottery(uint256 requestId, uint256[] memory randomWords) private {
        s_requests[requestId].fulfilled = true;
        s_requests[requestId].randomWords = randomWords;
        
        for (uint256 i = 0; i < participants.length; i++) {
            chances[participants[i]] = 0;
        }
        delete participants;
        tokensMinted = 0;
        
        emit RequestFulfilled(requestId, randomWords);
    }

    /**
     * @notice Permet de définir un nouveau coordinateur VRF.
     * @dev Cette fonction est désactivée car le coordinateur est immutable.
     * @param newCoordinator Adresse du nouveau coordinateur (non utilisé).
     *
     * Requirements:
     * - `newCoordinator` ne doit pas être l'adresse zéro.
     */
    function setCoordinator(address newCoordinator) external override onlyOwner {
        if (newCoordinator == address(0)) revert InvalidAddress();
        revert("Coordinator can't be changed - immutable");
    }

    /**
     * @notice Autorise la mise à niveau du contrat.
     * @dev Seul le propriétaire peut autoriser une mise à niveau.
     * @param newImplementation Adresse du nouveau contrat d'implémentation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Retourne la liste des participants actuels à la loterie.
     * @return Un tableau d'adresses représentant les participants.
     */
    function getParticipants() external view returns (address[] memory) {
        return participants;
    }

    /**
     * @notice Retourne le nombre de chances d'un participant.
     * @param participant Adresse du participant.
     * @return Le nombre de chances attribuées au participant.
     */
    function getChances(address participant) external view returns (uint256) {
        return chances[participant];
    }

    /**
     * @notice Réceptionne des paiements en Ether directement dans le contrat.
     * @dev Le montant reçu est ajouté au solde de la loterie.
     */
    receive() external payable {
        lotteryBalance += msg.value;
    }
}

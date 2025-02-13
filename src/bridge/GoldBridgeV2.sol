// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GoldBridge} from "./GoldBridge.sol";

/**
 * @title GoldBridgeV2
 * @notice Version améliorée du contrat GoldBridge intégrant un mécanisme de versioning.
 * @dev Hérite de GoldBridge et ajoute des fonctions permettant de récupérer la version du contrat.
 */
contract GoldBridgeV2 is GoldBridge {
    /// @notice Version actuelle du contrat.
    string internal constant VERSION = "2.0.0";

    /**
     * @notice Constructeur du contrat GoldBridgeV2.
     * @dev Transmet les paramètres au constructeur de GoldBridge.
     * @param _routerAddress Adresse du routeur Chainlink CCIP.
     * @param _goldToken Adresse du token GOLD.
     * @param _linkToken Adresse du token LINK.
     * @param _remoteContract Encodage de l'adresse du contrat distant.
     * @param _destinationChainId Identifiant de la chaîne de destination.
     *
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(
        address _routerAddress,
        address _goldToken,
        address _linkToken,
        bytes memory _remoteContract,
        uint64 _destinationChainId
    ) GoldBridge(
        _routerAddress,
        _goldToken,
        _linkToken,
        _remoteContract,
        _destinationChainId
    ) {}

    /**
     * @notice Retourne la version du contrat.
     * @return La version du contrat sous forme de chaîne de caractères.
     */
    function version() external pure returns (string memory) {
        return VERSION;
    }

    /**
     * @notice Retourne la version du contrat.
     * @return La version du contrat sous forme de chaîne de caractères.
     */
    function getVersion() external pure returns (string memory) {
        return VERSION;
    }
}

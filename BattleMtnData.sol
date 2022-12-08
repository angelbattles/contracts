//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/VRFConsumerBase.sol';

contract AccessControl {
    address payable public creatorAddress;
    uint16 public totalSeraphims = 0;
    mapping(address => bool) public seraphims;

    modifier onlyCREATOR() {
        require(msg.sender == creatorAddress, 'not creator');
        _;
    }

    modifier onlySERAPHIM() {
        require(seraphims[msg.sender] == true, 'permission');
        _;
    }

    // Constructor
    constructor() {
        creatorAddress = payable(msg.sender);
    }

    //Seraphims are contracts or addresses that have write access
    function addSERAPHIM(address _newSeraphim) public onlyCREATOR {
        if (seraphims[_newSeraphim] == false) {
            seraphims[_newSeraphim] = true;
            totalSeraphims += 1;
        }
    }

    function removeSERAPHIM(address _oldSeraphim) public onlyCREATOR {
        if (seraphims[_oldSeraphim] == true) {
            seraphims[_oldSeraphim] = false;
            totalSeraphims -= 1;
        }
    }

    function changeOwner(address payable _newOwner) public onlyCREATOR {
        creatorAddress = _newOwner;
    }
}

abstract contract IABToken is AccessControl {
    function ownerOf(uint256 tokenId) public view virtual returns (address);

    function getABToken(uint256 tokenId)
        public
        view
        virtual
        returns (
            uint8 cardSeriesId,
            uint16 power,
            uint16 auraRed,
            uint16 auraYellow,
            uint16 auraBlue,
            string memory name,
            uint16 experience,
            uint64 lastBattleTime,
            address owner,
            uint16 oldId
        );
}

abstract contract IBattleMtnStructure {
    function isValidMove(
        uint8 position,
        uint8 to,
        address battleMtnDataContract
    ) public view virtual returns (bool);

    function getSpotFromPanel(uint8 panel, uint8 spot)
        public
        view
        virtual
        returns (uint8);
}

contract BattleMtnData is AccessControl, VRFConsumerBase {
    /*** DATA TYPES ***/
    struct Team {
        uint256 angelId;
        uint256 petId;
        uint256 accessoryId;
        string slogan;
        uint8[8] defenderActions;
    }

    Team nullTeam;

    struct Panel {
        uint8[8] members;
    }

    Team[65] MTZion; //Array featuring info on the team at each position.

    mapping(uint256 => bool) public cardsOnBattleMtn;
    mapping(address => uint256) public ownerBalances;

    mapping(uint8 => bool) public cardsProhibited;
    mapping(address => bool) public playersAllowed;

    bool public playersRestricted = false;

    address public ABTokenDataContract = address(0);

    address public BattleMtnStructureContract = address(0);
    uint64 public delayTime = 0;
    uint64 public lastConditionChange = 0;

    uint8 public smallAuraEffect = 15;
    uint8 public bigAuraEffect = 30;
    uint8 public powerBoost = 3;
    uint8 public mudslideChance = 25;
    uint8 public defenseBuff = 20;
    bool public pendingCommit = false;

    // balance allocated to users but not yet claimed
    uint256 _reservedBalance = 0;

    //Determine current status such as which bridge is out.
    struct Conditions {
        uint8 auraBonus;
        uint8 petTypeBonus;
        uint8 lightAngelBonus;
        uint8 attackerBonus;
        uint8 petLevelBonus;
        uint8 bonusLevel;
        bool bridge1;
        bool bridge2;
        bool bridge3;
        bool superBerakiel;
        uint256 lastPayoutTime;
        uint256 lastPayoutValue;
        uint8 lastPayoutPanel;
    }

    Conditions currentConditions;
    Panel panel;

    address private committedSeed;
    uint256 private committedBlock;

    mapping(uint8 => uint8) public specialLocation;

    bytes32 internal keyHash;
    uint256 internal fee;

    uint8 public distFactor = 25;

    event Mudslide(uint256 angelId);

    // write functions

    function setCardDataContact(address _cardDataContract)
        external
        onlyCREATOR
    {
        ABTokenDataContract = _cardDataContract;
    }

    function setBattleMtnStructureContact(address _battleMtnStructureContract)
        external
        onlyCREATOR
    {
        BattleMtnStructureContract = _battleMtnStructureContract;
    }

   constructor()
        public
        VRFConsumerBase(
            0x3d2341ADb2D31f1c5530cDC622016af293177AE0, // VRF Coordinator
            0xb0897686c545045aFc77CF20eC7A532E3120E0F1 // LINK Token
        )
    {
        keyHash = 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
        fee = 0.0001 * 10**18; // 0.0001 LINK
    }

    // Receive any ether sent to the contract.
    receive() external payable {}

    // Called once to initialize the mountain.
    function initMountain() external onlyCREATOR {
        nullTeam.angelId = 0;
        nullTeam.petId = 1;
        nullTeam.accessoryId = 2;

        for (uint256 i = 0; i < 65; i++) {
            MTZion[i] = nullTeam;
        }

        currentConditions.auraBonus = 0;
        currentConditions.petTypeBonus = 0;
        currentConditions.lightAngelBonus = 0;
        currentConditions.attackerBonus = 0;
        currentConditions.petLevelBonus = 0;
        currentConditions.superBerakiel = false;
        currentConditions.bonusLevel = 0;
        currentConditions.bridge1 = true;
        currentConditions.bridge2 = true;
        currentConditions.bridge3 = true;

        // Set lava lake - Panels[4]
        specialLocation[29] = 1;
        specialLocation[31] = 1;
        specialLocation[33] = 1;
        specialLocation[35] = 1;
        specialLocation[38] = 1;
        specialLocation[40] = 1;
        specialLocation[42] = 1;
        specialLocation[45] = 1;

        // Set Glacier Peak - Panels[3]
        specialLocation[8] = 2;
        specialLocation[10] = 2;
        specialLocation[17] = 2;
        specialLocation[19] = 2;
        specialLocation[24] = 2;
        specialLocation[26] = 2;
        specialLocation[34] = 2;
        specialLocation[37] = 2;

        // Set Sunlight Area - Panels[2]
        specialLocation[7] = 3;
        specialLocation[9] = 3;
        specialLocation[16] = 3;
        specialLocation[18] = 3;
        specialLocation[23] = 3;
        specialLocation[25] = 3;
        specialLocation[30] = 3;
        specialLocation[32] = 3;
    }

    function getRandomNumber(
        uint16 maxRandom,
        uint8 min,
        address privateAddress
    ) public view returns (uint8) {
        uint256 genNum = uint256(
            keccak256(abi.encodePacked(block.timestamp, privateAddress))
        );
        return uint8((genNum % (maxRandom - min + 1)) + min);
    }

    // Since mappings are false by default, we only want to set
    // card series that are prohibited
    function setCardProhibitedStatus(uint8 _cardSeries, bool _prohibited)
        external
        onlyCREATOR
    {
        cardsProhibited[_cardSeries] = _prohibited;
    }

    // Since mappings are false by default, we only want to set
    // players that are allowed.

    // By default, all players are allowed. If the mountain owner
    // sets one player to be allowed, all other players will
    // not be allowed.
    function setPlayerAllowed(address _player) external onlyCREATOR {
        playersRestricted = true;
        playersAllowed[_player] = true;
    }

    function getPlayerAllowed(address _player) public view returns (bool) {
        if (playersRestricted == false) {
            return true;
        }
        return playersAllowed[_player];
    }

    function getCardRestricted(uint8 _cardSeriesId) public view returns (bool) {
        return cardsProhibited[_cardSeriesId];
    }

    function setVariables(
        uint64 _delayTime,
        uint8 _smallAuraEffect,
        uint8 _bigAuraEffect,
        uint8 _powerBoost,
        uint8 _mudslideChance,
        uint8 _defenseBuff
    ) external onlyCREATOR {
        delayTime = _delayTime;
        smallAuraEffect = _smallAuraEffect;
        bigAuraEffect = _bigAuraEffect;
        powerBoost = _powerBoost;
        mudslideChance = _mudslideChance;
        defenseBuff = _defenseBuff;
    }

    function addTeam(
        uint8 toSpot,
        uint256 angelId,
        uint256 petId,
        uint256 accessoryId
    ) public onlySERAPHIM {
        Team memory team;
        team.angelId = angelId;
        team.petId = petId;
        team.accessoryId = accessoryId;

        //Team coming on needs to be added.
        cardsOnBattleMtn[angelId] = true;
        cardsOnBattleMtn[petId] = true;
        cardsOnBattleMtn[accessoryId] = true;

        //Team displaced needs to be removed from leaderboard

        uint256 angel2Id = MTZion[toSpot].angelId;
        uint256 pet2Id = MTZion[toSpot].petId;
        uint256 accessory2Id = MTZion[toSpot].accessoryId;
        cardsOnBattleMtn[angel2Id] = false;
        cardsOnBattleMtn[pet2Id] = false;
        cardsOnBattleMtn[accessory2Id] = false;

        MTZion[toSpot] = team;

        //Default action is just to attack.
        MTZion[toSpot].defenderActions[0] = 1;
        MTZion[toSpot].defenderActions[1] = 1;
        MTZion[toSpot].defenderActions[2] = 1;
        MTZion[toSpot].defenderActions[3] = 1;
        MTZion[toSpot].defenderActions[4] = 1;
        MTZion[toSpot].defenderActions[5] = 1;
    }

    // Will fail if the teams have moved from this spot since the battle started.
    function switchTeams(
        uint8 fromSpot,
        uint8 toSpot,
        uint256 attacker,
        uint256 defender
    ) public onlySERAPHIM {
        require(MTZion[toSpot].angelId == defender, 'E10');
        require(MTZion[fromSpot].angelId == attacker, 'E11');
        Team memory tempTeam;
        tempTeam = MTZion[toSpot];
        MTZion[toSpot] = MTZion[fromSpot];
        MTZion[fromSpot] = tempTeam;
    }

    function getCommitStatus() public view returns (bool) {
        return pendingCommit;
    }

    /**
     * Requests randomness
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) > fee,
            'Not enough LINK - fill contract with faucet'
        );
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        committedSeed = address(uint160(randomness));
        committedBlock = block.number;
    }

    function changeConditionsCommit() public {
        // Make sure that there is not a pending commit.
        // E1 - There is already a pending commit
        require(pendingCommit == false, 'E1');

        // Make sure that the proper amount of time has passed.
        // E2 - Not enough time has passed
        require(block.timestamp > (lastConditionChange + delayTime), 'E2');
        pendingCommit = true;
        getRandomNumber();
    }

    function changeConditionsReveal() public {
        uint8 random;

        // make sure at least 20 blocks have passed
        // E2 - Not enough time has passed
        require(block.number > committedBlock + 20, 'E2');

        // E3 - You must commit before revealing
        require(pendingCommit == true, 'E3');
        pendingCommit = false;

        address seed = committedSeed;
        committedSeed = address(0);

        lastConditionChange = uint64(block.timestamp);

        random = getRandomNumber(93, 0, seed) + 7;

        currentConditions.bonusLevel = 1;
        if (random < 40) {
            currentConditions.bonusLevel = 2;
        }
        if (random < 15) {
            currentConditions.petLevelBonus = 3;
        }

        random = getRandomNumber(100, 0, seed);
        currentConditions.auraBonus = 0;
        if (random < 48) {
            currentConditions.auraBonus = 1;
        }
        if (random < 40) {
            currentConditions.auraBonus = 2;
        }
        if (random < 32) {
            currentConditions.auraBonus = 3;
        }
        if (random < 24) {
            currentConditions.auraBonus = 4;
        }
        if (random < 16) {
            currentConditions.auraBonus = 5;
        }
        if (random < 8) {
            currentConditions.auraBonus = 6;
        }

        if (random > 85) {
            if (currentConditions.bridge1 == true) {
                currentConditions.bridge1 = false;
            } else {
                currentConditions.bridge1 = true;
            }
        }
        random = getRandomNumber(99, 0, seed) + 1;
        currentConditions.petTypeBonus = 0;
        if (random < 28) {
            currentConditions.petTypeBonus = 1;
        }
        if (random < 21) {
            currentConditions.petTypeBonus = 2;
        }
        if (random < 14) {
            currentConditions.petTypeBonus = 3;
        }
        if (random < 7) {
            currentConditions.petTypeBonus = 4;
        }

        if (random > 85) {
            if (currentConditions.bridge2 == true) {
                currentConditions.bridge2 = false;
            } else {
                currentConditions.bridge2 = true;
            }
        }

        random = getRandomNumber(98, 0, seed) + 2;
        currentConditions.lightAngelBonus = 0;
        if (random < 30) {
            currentConditions.lightAngelBonus = 1;
        }
        if (random < 12) {
            currentConditions.lightAngelBonus = 2;
        }

        if (random > 85) {
            if (currentConditions.bridge3 == true) {
                currentConditions.bridge3 = false;
            } else {
                currentConditions.bridge3 = true;
            }
        }

        random = getRandomNumber(97, 0, seed) + 3;
        currentConditions.attackerBonus = 0;
        if (random < 30) {
            currentConditions.attackerBonus = 1;
        }
        if (random < 15) {
            currentConditions.attackerBonus = 2;
        }

        random = getRandomNumber(95, 0, seed) + 5;
        currentConditions.petLevelBonus = 0;
        if (random < 30) {
            currentConditions.petLevelBonus = 5;
        }
        if (random < 22) {
            currentConditions.petLevelBonus = 4;
        }
        if (random < 15) {
            currentConditions.petLevelBonus = 3;
        }
        if (random < 9) {
            currentConditions.petLevelBonus = 2;
        }
        if (random < 4) {
            currentConditions.petLevelBonus = 1;
        }

        random = getRandomNumber(94, 0, seed) + 6;
        currentConditions.superBerakiel = false;
        if (random < 4) {
            currentConditions.superBerakiel = true;
        }

        if (address(this).balance > 0) {
            // 50% chance to pay out one of the panels
            uint8 payoutChance = getRandomNumber(50, 0, seed);
            if (payoutChance > 25) {
                if (random < 25) {
                    payBonus(0);
                    return;
                }
                if (random < 40) {
                    payBonus(1);
                    return;
                }
                if (random < 54) {
                    payBonus(2);
                    return;
                }
                if (random < 67) {
                    payBonus(3);
                    return;
                }
                if (random < 79) {
                    payBonus(4);
                    return;
                }
                if (random < 90) {
                    payBonus(5);
                    return;
                }
                if (random < 96) {
                    payBonus(6);
                    return;
                }
                payBonus(7);
            }
        }

        // Mudslides knock a random team off the mountain
        if (getRandomNumber(100, 0, seed) > mudslideChance) {
            // Find the spot to remove
            IBattleMtnStructure BattleMtnStructure = IBattleMtnStructure(
                BattleMtnStructureContract
            );

            uint8 slideSpot = BattleMtnStructure.getSpotFromPanel(
                getRandomNumber(7, 0, msg.sender),
                getRandomNumber(8, 1, msg.sender) - 1
            );

            // Team coming off needs to be removed
            cardsOnBattleMtn[MTZion[slideSpot].angelId] = false;
            cardsOnBattleMtn[MTZion[slideSpot].angelId] = false;
            cardsOnBattleMtn[MTZion[slideSpot].angelId] = false;

            emit Mudslide(MTZion[slideSpot].angelId);

            // Replace with the null team.
            MTZion[slideSpot] = nullTeam;
        }
    }

    function payBonus(uint8 _panel) internal {
        if (_reservedBalance >= address(this).balance) {
            return;
        }
        uint256 amount = (address(this).balance - _reservedBalance) /
            distFactor;

        // Add to the reserved balance.
        _reservedBalance = _reservedBalance + (amount * 8);

        address winner;

        uint256 winningAngel;
        IABToken ABTokenData = IABToken(ABTokenDataContract);
        IBattleMtnStructure BattleMtnStructure = IBattleMtnStructure(
            BattleMtnStructureContract
        );

        for (uint8 i = 0; i < 8; i++) {
            winningAngel = MTZion[
                BattleMtnStructure.getSpotFromPanel(_panel, i)
            ].angelId;
            // Find the owner of the winning angel
            (, , , , , , , , winner, ) = ABTokenData.getABToken(winningAngel);
            ownerBalances[winner] += amount;
        }

        currentConditions.lastPayoutPanel = _panel;
        currentConditions.lastPayoutTime = block.timestamp;
        currentConditions.lastPayoutValue = amount;
    }

    function getOwnerBalance(address _owner) public view returns (uint256) {
        return ownerBalances[_owner];
    }

    function claimOwnerBalance(address payable _owner) public {
        uint256 amount = ownerBalances[_owner];
        ownerBalances[_owner] = 0;
        _reservedBalance = _reservedBalance - amount;
        _owner.transfer(amount);
    }

    function getCurrentConditions()
        external
        view
        returns (
            uint8 auraBonus,
            uint8 petTypeBonus,
            uint8 lightAngelBonus,
            uint8 attackerBonus,
            uint8 petLevelBonus,
            bool superBerakiel,
            bool bridge1,
            bool bridge2,
            bool bridge3,
            uint8 bonusLevel,
            uint64 lastConditionChangeTime
        )
    {
        auraBonus = currentConditions.auraBonus;
        petTypeBonus = currentConditions.petTypeBonus;
        lightAngelBonus = currentConditions.lightAngelBonus;
        attackerBonus = currentConditions.attackerBonus;
        petLevelBonus = currentConditions.petLevelBonus;
        superBerakiel = currentConditions.superBerakiel;
        bonusLevel = currentConditions.bonusLevel;
        bridge1 = currentConditions.bridge1;
        bridge2 = currentConditions.bridge2;
        bridge3 = currentConditions.bridge3;
        lastConditionChangeTime = lastConditionChange;
    }

    function getPayoutInfo()
        external
        view
        returns (
            uint256 lastPayoutTime,
            uint256 lastPayoutValue,
            uint8 lastPayoutPanel,
            uint256 balance,
            uint256 reservedBalance
        )
    {
        lastPayoutTime = currentConditions.lastPayoutTime;
        lastPayoutPanel = currentConditions.lastPayoutPanel;
        lastPayoutValue = currentConditions.lastPayoutValue;
        balance = address(this).balance;
        reservedBalance = _reservedBalance;
    }

    //Verify whether a given team occupies a given spot.
    function verifyPosition(
        uint8 spot,
        uint64 angelId,
        uint64 petId,
        uint64 accessoryId
    ) external view returns (bool) {
        Team memory team;
        team = MTZion[spot];
        if (
            (team.angelId != angelId) ||
            (team.petId != petId) ||
            (team.accessoryId != accessoryId)
        ) {
            return false;
        }
        return true;
    }

    // Read access
    function cardOnBattleMtn(uint256 Id) external view returns (bool) {
        return cardsOnBattleMtn[Id];
    }

    // Verify card ownership and battle eligibility
    function checkBattleParameters(
        uint256 angelId,
        uint256 petId,
        uint256 accessoryId,
        uint8 fromSpot,
        address owner
    ) public view {
        IABToken ABTokenData = IABToken(ABTokenDataContract);

        //First of all make sure that the player is battling with cards they own.
        //E4 - not angel owner, E5 not pet owner, E6 not accessory owner
        require(ABTokenData.ownerOf(angelId) == owner, 'E4');
        require(ABTokenData.ownerOf(petId) == owner, 'E5');
        require(
            ((accessoryId == 0) || (ABTokenData.ownerOf(accessoryId) == owner)),
            'E6'
        );

        // Check if cards on mountain when entering from a gate
        // E7 -Angel already on mountain, E8 Pet already on mountain, E9 Accessory already on mountain
        if (fromSpot == 99) {
            // Check if cards are already on the mountain
            require(cardsOnBattleMtn[angelId] == false, 'E7');
            require(cardsOnBattleMtn[petId] == false, 'E8');
            require(
                ((accessoryId == 0) ||
                    (cardsOnBattleMtn[accessoryId] == false)),
                'E9'
            );
        }

        if (playersRestricted) {
            require(playersAllowed[owner] == true, 'player not allowed');
        }
        uint8 cardSeriesId;

        (cardSeriesId, , , , , , , , , ) = ABTokenData.getABToken(angelId);
        require(cardsProhibited[cardSeriesId] == false, 'angel prohibited');

        (cardSeriesId, , , , , , , , , ) = ABTokenData.getABToken(petId);
        require(cardsProhibited[cardSeriesId] == false, 'pet prohibited');

        (cardSeriesId, , , , , , , , , ) = ABTokenData.getABToken(accessoryId);
        require(cardsProhibited[cardSeriesId] == false, 'accessory prohibited');
    }

    //Returns the team at a certain position.
    function getTeamByPosition(uint8 _position)
        external
        view
        returns (
            uint8 position,
            uint256 angelId,
            uint256 petId,
            uint256 accessoryId,
            string memory slogan
        )
    {
        position = _position;
        angelId = MTZion[_position].angelId;
        petId = MTZion[_position].petId;
        accessoryId = MTZion[_position].accessoryId;
        slogan = MTZion[_position].slogan;
    }

    function setSlogan(uint8 position, string memory _slogan) public {
        IABToken ABTokenData = IABToken(ABTokenDataContract);
        require(
            ABTokenData.ownerOf(MTZion[position].angelId) == msg.sender,
            'not owner'
        );
        //can only set slogans for angels you own.
        MTZion[position].slogan = _slogan;
    }

    // Set actions for future battles when your team is a defender.
    function setActions(
        uint8 position,
        uint8 action0,
        uint8 action1,
        uint8 action2,
        uint8 action3,
        uint8 action4,
        uint8 action5
    ) public {
        IABToken ABTokenData = IABToken(ABTokenDataContract);
        if (ABTokenData.ownerOf(MTZion[position].angelId) != msg.sender) {
            revert();
        }
        //can only set actions for teams you own.

        MTZion[position].defenderActions[0] = action0;
        MTZion[position].defenderActions[1] = action1;
        MTZion[position].defenderActions[2] = action2;
        MTZion[position].defenderActions[3] = action3;
        MTZion[position].defenderActions[4] = action4;
        MTZion[position].defenderActions[5] = action5;
    }

    //action 1 = attack, 2 = defend, 3 = auraBurst, 4 = release pet.

    function getAction(uint8 position, uint8 actionNumber)
        public
        view
        returns (uint8)
    {
        if (MTZion[position].defenderActions[actionNumber] > 0) {
            return MTZion[position].defenderActions[actionNumber];
        }
        // Return 1 (attack) if no option specified.
        return 1;
    }

    function applyConditions(
        uint256 angelId,
        uint256 petId,
        uint256 accessoryId,
        bool attacker,
        uint8 toSpot
    )
        public
        view
        returns (
            uint8 newPower,
            uint8 newSpeed,
            uint16 newRed,
            uint16 newYellow,
            uint16 newBlue
        )
    {
        uint8 angelSeriesId;
        uint8 petSeriesId;
        uint8 accSeriesId;

        IABToken ABTokenData = IABToken(ABTokenDataContract);

        (, , newRed, newYellow, newBlue, , , , , ) = ABTokenData.getABToken(
            petId
        );

        // Accessory Bonuses
        (accSeriesId, , , , , , , , , ) = ABTokenData.getABToken(accessoryId);

        if (accSeriesId == 43) {
            newPower += smallAuraEffect;
        } else if (accSeriesId == 44) {
            newPower += bigAuraEffect;
        } else if (accSeriesId == 47) {
            newSpeed += smallAuraEffect;
        } else if (accSeriesId == 48) {
            newSpeed += bigAuraEffect;
        } else if (accSeriesId == 49) {
            newRed += smallAuraEffect;
        } else if (accSeriesId == 50) {
            newRed += bigAuraEffect;
        } else if (accSeriesId == 51) {
            newYellow += smallAuraEffect;
        } else if (accSeriesId == 52) {
            newYellow += bigAuraEffect;
        } else if (accSeriesId == 53) {
            newBlue += smallAuraEffect;
        } else if (accSeriesId == 54) {
            newBlue += bigAuraEffect;
        }

        // Angel Aura Bonuses
        (angelSeriesId, , , , , , , , , ) = ABTokenData.getABToken(angelId);
        if (currentConditions.auraBonus == getAuraCode(angelId)) {
            newPower += powerBoost * currentConditions.bonusLevel;
        }

        // account for spot specific bonuses

        // 1 - blue, 2 - yellow, 3 - purple, 4 orange 5 - red, 6 green.
        uint8 auraCode = getAuraCode(angelId);

        // If in volcano, red aura angels get big aura bonus
        // orange and purple get small bonus

        if (specialLocation[toSpot] == 1) {
            if (auraCode == 5) {
                newPower += bigAuraEffect * currentConditions.bonusLevel;
            }

            if ((auraCode == 3) || (auraCode == 4)) {
                newPower += smallAuraEffect * currentConditions.bonusLevel;
            }
        }

        // If in glacier, blue aura angels get big aura bonus
        // green and purple get small bonus

        if (specialLocation[toSpot] == 2) {
            if (auraCode == 1) {
                newPower += bigAuraEffect * currentConditions.bonusLevel;
            }

            if ((auraCode == 3) || (auraCode == 6)) {
                newPower += smallAuraEffect * currentConditions.bonusLevel;
            }
        }

        // If in sunlight, yellow aura angels get big aura bonus
        // green and orange get small bonus

        if (specialLocation[toSpot] == 3) {
            if (auraCode == 2) {
                newPower += bigAuraEffect * currentConditions.bonusLevel;
            }

            if ((auraCode == 4) || (auraCode == 6)) {
                newPower += smallAuraEffect * currentConditions.bonusLevel;
            }
        }

        // Angel Type Bonus
        if (
            (currentConditions.lightAngelBonus == 1) &&
            (isLightAngel(angelSeriesId) == true)
        ) {
            newPower += powerBoost * currentConditions.bonusLevel;
        } else if (
            (currentConditions.lightAngelBonus == 2) &&
            (isLightAngel(angelSeriesId) == false)
        ) {
            newPower += powerBoost * currentConditions.bonusLevel;
        }

        // Holy Light bonus

        if (toSpot != 99) {
            uint8 defenderAngelSeriesId;
            (defenderAngelSeriesId, , , , , , , , , ) = ABTokenData.getABToken(
                MTZion[toSpot].angelId
            );
            if (
                isLightAngel(angelSeriesId) == true &&
                isLightAngel(defenderAngelSeriesId) == false &&
                accSeriesId == 60
            ) {
                newPower += 50;
            }
        }

        // Angel Attacker Bonus
        if (currentConditions.attackerBonus == 1 && attacker == true) {
            newPower += powerBoost * currentConditions.bonusLevel;
        } else if (currentConditions.attackerBonus == 2 && attacker == false) {
            newPower += powerBoost * currentConditions.bonusLevel;
        }

        // Pet Type Bonuses
        (petSeriesId, , , , , , , , , ) = ABTokenData.getABToken(petId);

        if (
            (currentConditions.petTypeBonus == 1) &&
            (petSeriesId == 24 ||
                petSeriesId == 28 ||
                petSeriesId == 32 ||
                petSeriesId == 36)
        ) {
            newSpeed += powerBoost * currentConditions.bonusLevel;
        } else if (
            (currentConditions.petTypeBonus == 2) &&
            (petSeriesId == 25 ||
                petSeriesId == 29 ||
                petSeriesId == 33 ||
                petSeriesId == 37)
        ) {
            newSpeed += powerBoost * currentConditions.bonusLevel;
        } else if (
            (currentConditions.petTypeBonus == 3) &&
            (petSeriesId == 26 ||
                petSeriesId == 30 ||
                petSeriesId == 34 ||
                petSeriesId == 38)
        ) {
            newSpeed += powerBoost * currentConditions.bonusLevel;
        } else if (
            (currentConditions.petTypeBonus == 4) &&
            (petSeriesId == 27 ||
                petSeriesId == 31 ||
                petSeriesId == 35 ||
                petSeriesId == 39)
        ) {
            newSpeed += powerBoost * currentConditions.bonusLevel;
        }

        // Pet Level Bonuses
        if ((currentConditions.petLevelBonus == 1) && (petSeriesId <= 27)) {
            newSpeed += powerBoost * currentConditions.bonusLevel;
        } else if (
            (currentConditions.petLevelBonus == 2) &&
            (petSeriesId >= 28) &&
            (petSeriesId <= 31)
        ) {
            newSpeed += powerBoost * currentConditions.bonusLevel;
        } else if (
            (currentConditions.petLevelBonus == 3) &&
            (petSeriesId >= 32) &&
            (petSeriesId <= 35)
        ) {
            newSpeed += powerBoost * currentConditions.bonusLevel;
        } else if (
            (currentConditions.petLevelBonus == 4) &&
            (petSeriesId >= 36) &&
            (petSeriesId <= 39)
        ) {
            newSpeed += powerBoost * currentConditions.bonusLevel;
        }

        if (currentConditions.superBerakiel == true && angelSeriesId == 0) {
            newPower += powerBoost * currentConditions.bonusLevel * 5;
        }
    }

    // Returns whether an angel is a light angel or a dark angel
    function isLightAngel(uint8 angelSeriesId) public pure returns (bool) {
        if (
            (angelSeriesId == 2) ||
            (angelSeriesId == 6) ||
            (angelSeriesId == 8) ||
            (angelSeriesId == 10) ||
            (angelSeriesId == 12) ||
            (angelSeriesId == 19) ||
            (angelSeriesId == 20) ||
            (angelSeriesId == 21)
        ) {
            return false;
        }
        return true;
    }

    function getTurnResult(
        uint8 round,
        uint8 spotContested,
        uint8 desiredAction,
        uint16 power,
        uint8 aura,
        uint8 petAuraStatus
    )
        public
        view
        returns (
            uint8 action,
            uint16 resultValue,
            uint8 newPetAuraStatus
        )
    {
        //If spotContested == 100, then this is an attacker's turn and use the sent value of desiredAction. Ignore round.
        //otherwise, read the defender's proscribed action from memory.
        if (spotContested != 100) {
            if (round > 6) {
                round = round % 6;
            }
            desiredAction = getAction(spotContested, round);
        }
        if (desiredAction == 0) {
            desiredAction = 1;
        } //default to attack in case of fighting a null team or a team that has not specified actions

        //00- neither released, 10- pet summoned, aura not yet, 01 - pet not yet, aura released, 11- both released.
        if (desiredAction == 3 && (petAuraStatus == 1 || petAuraStatus == 11)) {
            desiredAction = 1;
        }
        if (
            desiredAction == 4 && (petAuraStatus == 10 || petAuraStatus == 11)
        ) {
            desiredAction = 1;
        }

        //attack
        if (desiredAction == 1) {
            action = 1;
            if (power <= 120) {
                resultValue = getRandomNumber(power, 0, msg.sender);
            } else {
                resultValue = getRandomNumber(
                    power,
                    uint8(power - 120),
                    msg.sender
                );
            }
        }
        //defend
        if (desiredAction == 2) {
            uint8 extraDefense = getRandomNumber(50, 25, msg.sender);
            action = 4;
            resultValue = extraDefense;
        }
        //auraBurst
        if (desiredAction == 3) {
            uint8 chance = getRandomNumber(100, 0, msg.sender);

            //blue
            if (aura == 0) {
                action = 8;
                newPetAuraStatus = 1;
            }
            //yellow
            if (aura == 1) {
                action = 12;
            }

            //purple
            if (aura == 2) {
                if (chance >= 92) {
                    action = 10;
                } else {
                    action = 9;
                }
            }
            //orange
            if (aura == 3) {
                action = 13;
            }
            //red
            if (aura == 4) {
                action = 14;
                resultValue = getRandomNumber(power * 4, 0, msg.sender);
            }
            //green
            if (aura == 5) {
                action = 11;
            }

            if (petAuraStatus == 10) {
                newPetAuraStatus = 11;
            }
            if (petAuraStatus == 0) {
                newPetAuraStatus = 1;
            }
        }

        //summon pet
        if (desiredAction == 4) {
            if (petAuraStatus == 0) {
                newPetAuraStatus = 10;
            }
            if (petAuraStatus == 1) {
                newPetAuraStatus = 11;
            }

            uint16 petEffect = 0;
            uint8 petAction = getRandomNumber(100, 0, msg.sender);
            if (petAction < 15) {
                action = 15;
            }
            if (petAction > 14 && petAction < 50) {
                action = 16;
                petEffect = getRandomNumber(70, 30, msg.sender);
            }
            if (petAction > 49 && petAction < 70) {
                action = 17;
            }

            if (petAction > 69) {
                action = 18;

                petEffect = 50;
            }
            resultValue = petEffect;
        }
    }

    //Function that returns an Aura number 1 - blue, 2 - yellow, 3 - purple, 4 orange 5 - red, 6 green.
    function getAuraCode(uint256 angelId) public view returns (uint8) {
        IABToken ABTokenData = IABToken(ABTokenDataContract);
        uint16 red;
        uint16 yellow;
        uint16 blue;

        (, , red, yellow, blue, , , , , ) = ABTokenData.getABToken(angelId);
        if ((red == 0) && (yellow == 0)) {
            return 1;
        }
        if ((red == 0) && (blue == 0)) {
            return 2;
        }
        if ((red == 1) && (blue == 1)) {
            return 3;
        }
        if ((red == 1) && (yellow == 1)) {
            return 4;
        }
        if ((blue == 0) && (yellow == 0)) {
            return 5;
        }
        if ((blue == 1) && (yellow == 1)) {
            return 6;
        }
        //Something went wrong
        return 100;
    }

    function applyAuraColorDifference(
        uint256 angelId,
        uint16 power,
        uint8 toSpot
    ) public view virtual returns (uint16) {
        uint8 attackerAura = getAuraCode(angelId);
        uint8 defenderAura = getAuraCode(MTZion[toSpot].angelId);

        int8 differential = findAngelColorDifference(
            attackerAura,
            defenderAura
        );

        if (differential < 0) {
            // Return a minumum battle power in case the aura differences are ever greater
            // than the angel battle power
            if (uint8(differential * -1) >= power) {
                return 5;
            }
            return power - uint8(differential * -1);
        }
        return power + uint8(differential);
    }

    function findAngelColorDifference(uint8 attackerAura, uint8 defenderAura)
        public
        view
        returns (int8)
    {
        if (attackerAura == defenderAura) {
            return 0;
        }
        // Attacker is blue
        if (attackerAura == 1) {
            // large adv vs red
            if (defenderAura == 5) {
                return int8(bigAuraEffect);
            }
            // large disadv vs yellow
            if (defenderAura == 2) {
                return -int8(bigAuraEffect);
            }
            // small disadv vs green
            if (defenderAura == 6) {
                return -int8(smallAuraEffect);
            }
            // small adv vs purple
            if (defenderAura == 3) {
                return int8(smallAuraEffect);
            }
            // no advantage vs orange
            return 0;
        }

        // Attacker is yellow
        if (attackerAura == 2) {
            // large adv vs blue
            if (defenderAura == 1) {
                return int8(bigAuraEffect);
            }
            // large disadv vs red
            if (defenderAura == 5) {
                return -int8(bigAuraEffect);
            }
            // small disadv vs orange
            if (defenderAura == 4) {
                return -int8(smallAuraEffect);
            }
            // small adv vs green
            if (defenderAura == 6) {
                return int8(smallAuraEffect);
            }
            // no advantage vs purple
            return 0;
        }

        // Attacker is purple
        if (attackerAura == 3) {
            // small disadv vs orange and blue
            if (defenderAura == 4 || defenderAura == 1) {
                return -int8(smallAuraEffect);
            }
            // small adv vs red and green
            if (defenderAura == 5 || defenderAura == 6) {
                return int8(smallAuraEffect);
            }
            // no advantage vs yellow
            return 0;
        }

        // Attacker is orange
        if (attackerAura == 4) {
            // small disadv vs red and green
            if (defenderAura == 5 || defenderAura == 6) {
                return -int8(smallAuraEffect);
            }
            // small adv vs yellow and purple
            if (defenderAura == 2 || defenderAura == 3) {
                return int8(smallAuraEffect);
            }
            // no advantage vs blue
            return 0;
        }

        // Attacker is red
        if (attackerAura == 5) {
            // large adv vs yellow
            if (defenderAura == 2) {
                return int8(bigAuraEffect);
            }
            // large disadv vs blue
            if (defenderAura == 1) {
                return -int8(bigAuraEffect);
            }
            // small disadv vs purple
            if (defenderAura == 3) {
                return -int8(smallAuraEffect);
            }
            // small adv vs orange
            if (defenderAura == 4) {
                return int8(smallAuraEffect);
            }
            // no advantage vsgreen
            return 0;
        }

        // Attacker is green
        if (attackerAura == 6) {
            // small disadv vs yellow and purple
            if (defenderAura == 2 || defenderAura == 3) {
                return -int8(smallAuraEffect);
            }
            // small adv vs organge and blue
            if (defenderAura == 4 || defenderAura == 1) {
                return int8(smallAuraEffect);
            }
            // no advantage vs red
            return 0;
        }
        return 0;
    }

    function isValidMove(
        uint8 position,
        uint8 to,
        address battleMtnDataContract
    ) public view returns (bool) {
        IBattleMtnStructure BattleMtnStructure = IBattleMtnStructure(
            BattleMtnStructureContract
        );

        return
            BattleMtnStructure.isValidMove(position, to, battleMtnDataContract);
    }
}

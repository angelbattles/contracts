//SPDX-License-Identifier: MIT License
pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/VRFConsumerBase.sol';

contract AccessControl {
    address payable public creatorAddress;

    modifier onlyCREATOR() {
        require(msg.sender == creatorAddress, 'You are not the creator');
        _;
    }

    // Constructor
    constructor() {
        creatorAddress = payable(msg.sender);
    }

    function changeOwner(address payable _newOwner) public onlyCREATOR {
        creatorAddress = _newOwner;
    }
}

abstract contract IABToken is AccessControl {
    function mintABToken(
        address owner,
        uint8 _cardSeriesId,
        uint16 _power,
        uint16 _auraRed,
        uint16 _auraYellow,
        uint16 _auraBlue,
        string memory _name,
        uint16 _experience
    ) public virtual;

    function totalSupply() public virtual returns (uint256);
}

abstract contract IHalo {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual returns (bool);
}

contract ABStore is AccessControl, VRFConsumerBase {
    address public ABTokenDataContract;
    address payable public BattleMtnAddress;

    struct UltimatePackCommit {
        uint256 randomNumber;
        uint256 blockNumber;
    }

    address[] public pendingAddresses;

    mapping(address => UltimatePackCommit) public ultimatePackCommits;

    uint256 public bronzePrice = 100;
    uint256 public silverPrice = 200;
    uint256 public goldPrice = 300;

    // Price in Halo tokens for the special pack
    uint256 public specialPackHaloPrice = 1000000000000000000000;
    address public haloContractAddress = address(0);
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    uint256 public sentValue = 0;

    bytes32 internal keyHash;
    uint256 internal fee;

    constructor()
        public
        VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB // LINK Token
        )
    {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.0001 * 10**18; // 0.0001 LINK
    }

    // Called once to initialize the store.
    function initStore() external onlyCREATOR {
        IABToken abTokenContract = IABToken(ABTokenDataContract);
        require(
            abTokenContract.totalSupply() == 0,
            'There are already tokens in the ABTokenDataContract'
        );

        // First three tokens are the null team for battle mountain
        // Create Berakiel
        abTokenContract.mintABToken(address(this), 0, 60, 0, 0, 1, '', 0);

        // Create the Pet
        abTokenContract.mintABToken(address(this), 24, 1, 2, 2, 2, '', 0);

        // Create the accessory
        abTokenContract.mintABToken(address(this), 43, 0, 0, 0, 0, '', 0);
    }

    function setPackPrices(
        uint256 _bronzePrice,
        uint256 _silverPrice,
        uint256 _goldPrice,
        uint256 _specialPackHaloPrice
    ) public onlyCREATOR {
        bronzePrice = _bronzePrice;
        silverPrice = _silverPrice;
        goldPrice = _goldPrice;
        specialPackHaloPrice = _specialPackHaloPrice;
    }

    function setHaloAddress(address _haloContractAddress) public onlyCREATOR {
        haloContractAddress = _haloContractAddress;
    }

    function getFreePack() public {
        IABToken abTokenContract = IABToken(ABTokenDataContract);

        // Create Berakiel
        uint16 power;
        (power) = getAngelPower(0);
        abTokenContract.mintABToken(msg.sender, 0, power, 0, 0, 1, '', 0);

        // Create the Pet
        uint8 petSeries = chooseFreePet();
        uint8 petSpeed = getRandomNumber(19, 10, msg.sender);
        abTokenContract.mintABToken(
            msg.sender,
            petSeries,
            petSpeed,
            getRandomNumber(5, 0, msg.sender),
            getRandomNumber(4, 0, msg.sender) + 1,
            getRandomNumber(3, 0, msg.sender) + 2,
            '',
            0
        );
    }

    function buyBronzePack() public payable {
        IABToken abTokenContract = IABToken(ABTokenDataContract);

        require(msg.value >= bronzePrice, 'You need to send the bronze price');

        // Create the Angel
        mintAngel(chooseBronzeAngel());

        // Create the Pet
        uint8 petSeries = chooseBronzeSilverPet();
        uint8 petSpeed = getRandomNumber(29, 20, msg.sender);
        abTokenContract.mintABToken(
            msg.sender,
            petSeries,
            petSpeed,
            getRandomNumber(10, 5, msg.sender),
            getRandomNumber(9, 5, msg.sender) + 1,
            getRandomNumber(8, 5, msg.sender) + 2,
            '',
            0
        );
    }

    function buySilverPack() public payable {
        IABToken abTokenContract = IABToken(ABTokenDataContract);

        require(msg.value >= silverPrice, 'You need to send the silver price');

        // Create the Angel
        mintAngel(chooseSilverAngel());

        // Create the Pet
        uint8 petSeries = chooseBronzeSilverPet();
        uint8 petSpeed = getRandomNumber(29, 20, msg.sender);
        abTokenContract.mintABToken(
            msg.sender,
            petSeries,
            petSpeed,
            getRandomNumber(10, 5, msg.sender),
            getRandomNumber(8, 5, msg.sender) + 2,
            getRandomNumber(9, 5, msg.sender) + 1,
            '',
            0
        );

        // Create the accessory
        uint8 accSeries = chooseSilverAccessory();
        abTokenContract.mintABToken(msg.sender, accSeries, 0, 0, 0, 0, '', 0);
    }

    function buyGoldPack() public payable {
        IABToken abTokenContract = IABToken(ABTokenDataContract);

        require(msg.value >= goldPrice, 'You need to send the gold price');

        // Create the Angel
        mintAngel(chooseGoldAngel());

        // Create the Pet
        uint8 petSeries = chooseGoldPet();
        uint8 petSpeed = getRandomNumber(39, 30, msg.sender);
        abTokenContract.mintABToken(
            msg.sender,
            petSeries,
            petSpeed,
            getRandomNumber(13, 10, msg.sender) + 2,
            getRandomNumber(15, 10, msg.sender),
            getRandomNumber(14, 10, msg.sender) + 1,
            '',
            0
        );

        // Create the accessory
        uint8 accSeries = chooseGoldAccessory();
        abTokenContract.mintABToken(msg.sender, accSeries, 0, 0, 0, 0, '', 0);
    }

    function chooseSilverAccessory() public view returns (uint8) {
        uint8 choice = getRandomNumber(100, 1, msg.sender);
        // Leather bracers
        if (choice <= 15) {
            return 43;
        }
        // Metal bracers
        if (choice <= 20) {
            return 44;
        }
        // Scholars Scroll
        if (choice <= 35) {
            return 45;
        }
        // Cosmic Scroll
        if (choice <= 40) {
            return 46;
        }
        // Red collar
        if (choice <= 55) {
            return 49;
        }
        // Ruby Collar
        if (choice <= 60) {
            return 50;
        }
        // Yellow collar
        if (choice <= 75) {
            return 51;
        }
        // Citrine Collar
        if (choice <= 80) {
            return 52;
        }
        // Blue collar
        if (choice <= 95) {
            return 53;
        }
        // Sapphire Collar
        return 54;
    }

    function chooseGoldAccessory() public view returns (uint8) {
        uint8 choice = getRandomNumber(101, 2, msg.sender);

        // 50% chance to get silver level accessory
        if (choice <= 50) {
            return chooseSilverAccessory();
        }

        // Carrots
        if (choice < 63) {
            return 55;
        }

        // Cricket
        if (choice < 76) {
            return 56;
        }

        // Bird Seed
        if (choice < 89) {
            return 57;
        }

        // Cat Nip

        return 58;
    }

    function chooseBronzeAngel() public view returns (uint8) {
        uint8 choice = getRandomNumber(100, 1, msg.sender);
        // Arel
        if (choice <= 28) {
            return 4;
        }
        // Raguel
        if (choice <= 52) {
            return 5;
        }
        // Lilith
        if (choice <= 72) {
            return 6;
        }
        // Furlac
        if (choice <= 86) {
            return 7;
        }
        // Azazel
        if (choice <= 95) {
            return 8;
        }
        // Eleleth
        return 9;
    }

    function chooseSilverAngel() public view returns (uint8) {
        uint8 choice = getRandomNumber(100, 1, msg.sender);
        // Verin
        if (choice <= 20) {
            return 10;
        }
        // Ziwa
        if (choice <= 37) {
            return 11;
        }
        // Cimeriel
        if (choice <= 52) {
            return 12;
        }
        // Numinel
        if (choice <= 65) {
            return 13;
        }
        // Bat Gol
        if (choice <= 76) {
            return 14;
        }
        // Gabriel
        if (choice <= 85) {
            return 15;
        }
        // Metatron
        if (choice <= 92) {
            return 16;
        }
        // Rafael
        if (choice <= 97) {
            return 17;
        }
        // Melchezidek
        return 18;
    }

    function chooseGoldAngel() public view returns (uint8) {
        uint8 choice = getRandomNumber(100, 1, msg.sender);
        // Semyaza
        if (choice <= 30) {
            return 19;
        }
        // Abbadon
        if (choice <= 55) {
            return 20;
        }
        // Baalzebub
        if (choice <= 75) {
            return 21;
        }
        // Ben Nez
        if (choice <= 90) {
            return 22;
        }
        // Jophiel
        return 23;
    }

    // Level 1 pet
    function chooseFreePet() public view returns (uint8) {
        uint8 choice = getRandomNumber(100, 1, msg.sender);
        // Gecko
        if (choice <= 50) {
            return 24;
        }
        // Parakeet
        if (choice <= 75) {
            return 25;
        }
        // Angry Kitty
        if (choice <= 90) {
            return 26;
        }
        // Horse
        return 27;
    }

    // Level 2 pet
    function chooseBronzeSilverPet() public view returns (uint8) {
        uint8 choice = getRandomNumber(100, 1, msg.sender);
        // Komodo
        if (choice <= 50) {
            return 28;
        }
        // Falcon
        if (choice <= 75) {
            return 29;
        }
        // Bobcat
        if (choice <= 90) {
            return 30;
        }
        // Unicorn
        return 31;
    }

    // Level 3 pet
    function chooseGoldPet() public view returns (uint8) {
        uint8 choice = getRandomNumber(100, 1, msg.sender);
        // Rock Dragon
        if (choice <= 50) {
            return 32;
        }
        // Archaeopteryx
        if (choice <= 75) {
            return 33;
        }
        // Sabertooth
        if (choice <= 90) {
            return 34;
        }
        // Pegasus
        return 35;
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        address committedAddress = pendingAddresses[
            pendingAddresses.length - 1
        ];
        pendingAddresses.pop();
        ultimatePackCommits[committedAddress].randomNumber =
            (randomness % 99) +
            1;
    }

    /**
     * Requests randomness
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) > fee,
            'Not enough LINK - someone must add to contract'
        );
        return requestRandomness(keyHash, fee);
    }

    // The best cards can only be obtained by burning Halo tokens
    function commitToBuySpecialPack() public {
        require(
            ultimatePackCommits[msg.sender].randomNumber == 0,
            'You have already committed'
        );

        require(
            ultimatePackCommits[msg.sender].blockNumber == 0,
            'Commit in progress'
        );

        IHalo Halo = IHalo(haloContractAddress);

        // Will fail if user does not have enough Halo tokens
        Halo.transferFrom(msg.sender, deadAddress, specialPackHaloPrice);

        UltimatePackCommit memory commit;

        commit.blockNumber = block.number;
        commit.randomNumber = 0;

        ultimatePackCommits[msg.sender] = commit;
        pendingAddresses.push(msg.sender);

        // Call chainlink  vrf to get random number
        getRandomNumber();
    }

    // To protect from various flashbots bundle enabled attacks
    // users must first commit to buy the special pack by burning HALO tokens
    // The receiveSpecialPack() function can be called a minimum of 10 blocks later
    function receiveSpecialPack() public {
        require(
            block.number > ultimatePackCommits[msg.sender].blockNumber + 20,
            'You need to wait longer'
        );
        require(
            ultimatePackCommits[msg.sender].randomNumber != 0,
            'You need to commit first'
        );
        IABToken abTokenContract = IABToken(ABTokenDataContract);

        uint256 choice = ultimatePackCommits[msg.sender].randomNumber;

        ultimatePackCommits[msg.sender].randomNumber = 0;
        ultimatePackCommits[msg.sender].blockNumber = 0;

        // Zadkiel
        if (choice <= 40) {
            mintAngel(1);
        }
        // Silver medal
        else if (choice > 40 && choice <= 60) {
            abTokenContract.mintABToken(msg.sender, 65, 0, 0, 0, 0, '', 0);
        }
        // Gold medal
        else if (choice > 60 && choice <= 75) {
            abTokenContract.mintABToken(msg.sender, 66, 0, 0, 0, 0, '', 0);
        }
        // Platinum medal
        else if (choice > 75 && choice <= 85) {
            abTokenContract.mintABToken(msg.sender, 67, 0, 0, 0, 0, '', 0);
        }
        // Lightning Rod
        else if (choice > 85 && choice <= 90) {
            abTokenContract.mintABToken(msg.sender, 59, 0, 0, 0, 0, '', 0);
        }
        // Holy Light Accessory
        else if (choice > 90 && choice <= 95) {
            abTokenContract.mintABToken(msg.sender, 60, 0, 0, 0, 0, '', 0);
        }
        // Lucifer
        else if (choice > 95 && choice <= 98) {
            mintAngel(2);
        }
        // Michael
        else {
            mintAngel(3);
        }
    }

    function getCommitStatus(address addressToCheck)
        public
        view
        returns (bool)
    {
        return ultimatePackCommits[addressToCheck].randomNumber != 0;
    }

    function mintAngel(uint8 _angelSeriesId) internal {
        IABToken abTokenContract = IABToken(ABTokenDataContract);
        (uint8 auraRed, uint8 auraYellow, uint8 auraBlue) = getAura(
            _angelSeriesId
        );
        uint16 power = getAngelPower(_angelSeriesId);
        abTokenContract.mintABToken(
            msg.sender,
            _angelSeriesId,
            power,
            auraRed,
            auraYellow,
            auraBlue,
            '',
            0
        );
    }

    function getAngelPower(uint8 _angelSeriesId) private view returns (uint16) {
        uint8 randomPower = getRandomNumber(10, 0, msg.sender);
        if (_angelSeriesId >= 4) {
            return
                uint16(100 + 10 * (uint16(_angelSeriesId) - 4) + randomPower);
        }
        if (_angelSeriesId == 0) {
            return (50 + randomPower);
        }
        if (_angelSeriesId == 1) {
            return (120 + randomPower);
        }
        if (_angelSeriesId == 2) {
            return (250 + randomPower);
        }
        if (_angelSeriesId == 3) {
            return (300 + randomPower);
        }
        return 1;
    }

    //Returns the Aura color of each angel
    function getAura(uint8 _angelSeriesId)
        public
        pure
        returns (
            uint8 auraRed,
            uint8 auraYellow,
            uint8 auraBlue
        )
    {
        if (_angelSeriesId == 0) {
            return (0, 0, 1);
        }
        if (_angelSeriesId == 1) {
            return (0, 1, 0);
        }
        if (_angelSeriesId == 2) {
            return (1, 0, 1);
        }
        if (_angelSeriesId == 3) {
            return (1, 1, 0);
        }
        if (_angelSeriesId == 4) {
            return (1, 0, 0);
        }
        if (_angelSeriesId == 5) {
            return (0, 1, 0);
        }
        if (_angelSeriesId == 6) {
            return (1, 0, 1);
        }
        if (_angelSeriesId == 7) {
            return (0, 1, 1);
        }
        if (_angelSeriesId == 8) {
            return (1, 1, 0);
        }
        if (_angelSeriesId == 9) {
            return (0, 0, 1);
        }
        if (_angelSeriesId == 10) {
            return (1, 0, 0);
        }
        if (_angelSeriesId == 11) {
            return (0, 1, 0);
        }
        if (_angelSeriesId == 12) {
            return (1, 0, 1);
        }
        if (_angelSeriesId == 13) {
            return (0, 1, 1);
        }
        if (_angelSeriesId == 14) {
            return (1, 1, 0);
        }
        if (_angelSeriesId == 15) {
            return (0, 0, 1);
        }
        if (_angelSeriesId == 16) {
            return (1, 0, 0);
        }
        if (_angelSeriesId == 17) {
            return (0, 1, 0);
        }
        if (_angelSeriesId == 18) {
            return (1, 0, 1);
        }
        if (_angelSeriesId == 19) {
            return (0, 1, 1);
        }
        if (_angelSeriesId == 20) {
            return (1, 1, 0);
        }
        if (_angelSeriesId == 21) {
            return (0, 0, 1);
        }
        if (_angelSeriesId == 22) {
            return (1, 0, 0);
        }
        if (_angelSeriesId == 23) {
            return (0, 1, 1);
        }
    }

    function setBattleMtnContract(address payable _BattleMtnAddress)
        public
        onlyCREATOR
    {
        BattleMtnAddress = _BattleMtnAddress;
    }

    function setABTokenDataContract(address _ABTokenDataContract)
        public
        onlyCREATOR
    {
        ABTokenDataContract = _ABTokenDataContract;
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

    function getStoreInfo()
        public
        view
        returns (uint256 totalSentValue, uint256 balance)
    {
        totalSentValue = sentValue;
        balance = address(this).balance;
    }

    function withdrawEther() public {
        uint256 value = address(this).balance;
        (bool success, ) = BattleMtnAddress.call{value: value}('');
        require(success, 'Gitcoin issue');
        sentValue += value;
    }
}

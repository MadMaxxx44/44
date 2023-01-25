// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

//deployed on goerli 0x4e50E36482Bd2B83169Dd58dCE71083d8891Dfc5

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract PuppyNFT is ERC721URIStorage, VRFConsumerBaseV2 {
    uint16 requestConfirmations = 3;
    uint32 callbackGasLimit = 300000;
    uint32 numWords = 2;
    uint64 s_subscriptionId;
    uint256 public tokenCounter;
    VRFCoordinatorV2Interface public COORDINATOR;
    enum Breed{PUG, SHIBA_INU, ST_BERNARD}
    mapping(uint => address) public requestIdToSender;
    mapping(Breed => string) public breedToTokenURI;
    mapping(uint256 => Breed) public tokenIdToBreed;
    mapping(uint => uint256) public requestIdToTokenId;
    event RequestedCollectible(uint indexed requestId); 
    event ReturnedCollectible(uint indexed requestId, uint256[] randomWords);
    bytes32 internal keyHash;
    
    constructor (
        uint64 _subscriptionId, 
        address _VRFCoordinator, 
        bytes32 _keyhash) 
    VRFConsumerBaseV2(_VRFCoordinator)
    ERC721("Dogie", "DOG")
    {
        COORDINATOR = VRFCoordinatorV2Interface(_VRFCoordinator);
        tokenCounter = 0;
        keyHash = _keyhash;
        s_subscriptionId = _subscriptionId;
        breedToTokenURI[Breed.PUG] = "https://gateway.pinata.cloud/ipfs/QmTKbNsDa2HpvMNzU3qsGzZBW8FVWy7fQ8dRJKVMvKQwJJ";
        breedToTokenURI[Breed.SHIBA_INU] = "https://gateway.pinata.cloud/ipfs/QmbQwo44FQpZvUaJxNaoaKDPocmucPyWMXd1rq692aQypP";
        breedToTokenURI[Breed.ST_BERNARD] = "https://gateway.pinata.cloud/ipfs/QmXSWzhqZYLvwehZF8ryAkvhCRkJV71TZg75ZnmGYUeVrv";
    }

    function createCollectible() public returns (uint) {
            uint requestId = COORDINATOR.requestRandomWords(
                keyHash, 
                s_subscriptionId,
                requestConfirmations,
                callbackGasLimit, 
                numWords
            );
            requestIdToSender[requestId] = msg.sender;
            emit RequestedCollectible(requestId);
            return requestId;
    }

    function fulfillRandomWords(uint requestId, uint256[] memory _randomWords) 
    internal override {
        address dogOwner = requestIdToSender[requestId];
        uint256 newItemId = tokenCounter;
        _safeMint(dogOwner, newItemId);
        Breed breed = Breed(_randomWords[0] % 3); 
        tokenIdToBreed[newItemId] = breed;
        if(breed == Breed.PUG) {
            _setTokenURI(newItemId, breedToTokenURI[Breed.PUG]); 
        }
        if(breed == Breed.SHIBA_INU) {
            _setTokenURI(newItemId, breedToTokenURI[Breed.SHIBA_INU]);
        }
        if(breed == Breed.ST_BERNARD) {
            _setTokenURI(newItemId, breedToTokenURI[Breed.ST_BERNARD]);
        }
        requestIdToTokenId[requestId] = newItemId;
        tokenCounter = tokenCounter + 1;
        emit ReturnedCollectible(requestId, _randomWords);
    }
}

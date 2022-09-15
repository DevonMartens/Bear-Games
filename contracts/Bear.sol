// SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;
import "./ERC721.sol";
import "./Pausable.sol";
import "./ERC721Enumerable.sol";
import "./interfaces/IBear.sol";
import "./interfaces/IForest.sol";
import "./interfaces/ITraits.sol";
import "./Honey.sol";
import "./ReentrancyGuard.sol";
import "./VRFConsumerBase.sol";

// add Ib
//imports need to cone
 //Cubs- honey bees- 
 //imports need to come from open zep



//payment splitter 
contract Bear is IBear, ERC721Enumerable, Ownable, Pausable, VRFConsumerBase {

  // mint price
  //setter and getter for mint
  //temp price for testnet
  uint256 public constant MINT_PRICE = .001 ether;
  //uint public MINT_PRICE;
  // max number of tokens that can be minted - 50000 in production
  uint256 public immutable MAX_TOKENS;
  // // number of tokens that can be claimed for free - 20% of MAX_TOKENS
  uint256 public PAID_TOKENS;
  // number of tokens have been minted so far
  uint16 public minted;
  //Veteran Price
  // uint256 public vetMintPrice = 8e16; //0.08 ETH
  // mapping from tokenId to a struct containing the token's traits
  mapping(uint256 => BeesCubs) public tokenTraits;
  // mapping from hashed(tokenTrait) to the tokenId it's associated with
  // used to ensure there are no duplicates
  mapping(uint256 => uint256) public existingCombinations;

  // list of probabilities for each trait type
  // 0 - 9 are associated with Bees, 10 - 18 are associated with Bears
  uint8[][20] public rarities;
  // list of aliases for Walker's Alias algorithm
  // 0 - 9 are associated with Bees, 10 - 18 are associated with Bears
  uint8[][20] public aliases;

  // reference to the Forest for choosing random Bear thieves
  IForest public forest;
  // reference to $HONEY for burning on mint
  address public honeyAddr = address(0);
  HONEY public honey;
  // reference to Traits
  address public traitsAddr = address(0);
  ITraits public traits;
  // reference to PaymentSplitter

  // used for Chainlink VRF
  bytes32 private vrfKeyHash;
  uint256 private vrfFee;
  uint256 private vrfRandomResult;
  // This is just an example mapping and can be removed/replaced with whatever you need to store the random number coming back from Chainlink
  mapping(bytes32 => uint) public vrfRandomnessRequestResult;

   event saleMade(address, bool, uint);
   
  /** 
   * instantiates contract and rarity tables
   */
  
  constructor(address _honey, address _traits, uint256 _maxTokens, address _vrfCoordinator, address _LINK, bytes32 _vrfKeyHash, uint256 _vrfFee) 
    ERC721("Bear Game", 'BGAME') VRFConsumerBase(
        _vrfCoordinator, // VRF Coordinator
        _LINK  // LINK Token
    )
  { 
    honey = HONEY(_honey);
    traits = ITraits(_traits);
    MAX_TOKENS = _maxTokens;
  
    PAID_TOKENS = _maxTokens / 5;

    vrfKeyHash = _vrfKeyHash;
    vrfFee = _vrfFee;

    //   uint256 public Price = 8e16; //0.08 ETH


    // I know this looks weird but it saves users gas by making lookup O(1)
    //may need to adjust based on traits
    // bees
    // background 0
    rarities[0] = [31, 90, 235, 245, 255, 235];
    aliases[0] = [2, 4, 3, 3, 5, 4];
    // basebody 8
    rarities[1] = [255];
    aliases[1] = [0];
    // wing(upperBody) 7
    rarities[2] = [255, 233, 230, 229, 224, 84, 29, 255, 240];
    aliases[2] = [1, 0, 5, 0, 1, 7, 1, 3, 7];
    // body 1
    rarities[3] = [255, 255, 255, 255, 255, 20, 80, 20, 255, 255, 255, 255, 80, 255, 255, 255];
    aliases[3] = [0, 1, 2, 3, 4, 3, 10, 11, 8, 9, 10, 11, 13, 13, 14, 15];
    // mouth 6
    rarities[4] = [243, 255, 230, 229, 255, 243, 255, 251, 225, 244, 71, 68, 245, 255, 245];
    aliases[4] = [0, 1, 1, 3, 4, 5, 6, 4, 8, 9, 9, 12, 13, 13, 14];
    // // ears 2
    rarities[5] =  [255];
    aliases[5] = [0];
    // eyes 3
    rarities[6] = [255, 251, 252, 83, 255, 77];
    aliases[6] = [0, 0, 4, 2, 5, 3];
    // face 4
	rarities[7] = [253, 255, 79, 85, 250, 246, 247, 244, 74, 253, 250, 243, 239, 22, 254, 21, 251, 242, 24, 247];
    aliases[7] = [0, 1, 1, 4, 4, 5, 6, 7, 9, 9, 10, 11, 12, 12, 14, 16, 16, 17, 19, 14];
    // head 5
    rarities[8] = [31, 78, 227, 228, 255, 28, 255, 245, 81, 243, 233, 255, 229, 254, 243, 255, 251, 225, 227, 228, 235, 23];
    aliases[8] = [3, 2, 4, 7, 6, 4, 10, 11, 12, 13, 14, 6, 16, 11, 18, 19, 19, 11, 20, 9, 3, 6];
    // senseIndex, void for bees 9
    rarities[9] = [255];
    aliases[9] = [0];

    // bears
    // background 10
    rarities[10] = [255, 29, 78, 240, 244, 245];
    aliases[10] = [0, 0, 3, 3, 5, 4];
    // basebody 18
    rarities[11] = [255];
    aliases[11] = [0];
    // body 11
    rarities[12] = [210, 255, 240, 31, 245, 244, 239, 84, 255, 29, 91];
    aliases[12] = [0, 1, 2, 1, 4, 4, 6, 8, 0, 5, 1];
    // neck(upperBody)) 17
    rarities[13] = [78, 76, 255, 19]; 
    aliases[13] = [2, 2, 2, 2];
    // head 15
    rarities[14] = [75, 25, 74, 238, 28, 255, 235, 230, 89, 81, 73, 241];
    aliases[14] = [5, 5, 5, 11, 11, 3, 3, 5, 6, 6, 7, 7];
    // ears 12
    rarities[15] = [24, 30, 33, 255];
    aliases[15] = [3, 3, 3, 3];
    // eyes 13
	rarities[16] = [235, 247, 239, 241, 76, 225, 235, 255];
    aliases[16] = [7, 7, 1, 3, 5, 6, 2, 0];
    // face 14       
    rarities[17] = [243, 252, 64, 241, 73, 236, 26, 233, 99, 34];
    aliases[17] = [1, 1, 0, 0, 3, 3, 5, 5, 7, 7];
    // mouth 16
    rarities[18] = [25, 237, 72, 246, 34, 255, 255, 239, 245, 235, 245, 239, 89, 230];
    aliases[18] = [6, 6, 6, 5, 5, 5, 4, 10, 10, 13, 13, 1, 1, 7];
    // senseIndex 19
    rarities[19] = [25, 160, 73, 255];
    aliases[19] = [2, 3, 3, 3];
  }
  // function setMintPrice(uint256 NEW_MINT_PRICE) public onlyOwner {
  //         MINT_PRICE = NEW_MINT_PRICE;
  // }
   
  /** EXTERNAL */

  /** 
  //Veteran Mint
   * mint a token - 90% Bees, 10% Cubs
   //that
   */

    // function addHoneyContract(address _honeyAddr) external onlyOwner {
    //     require(honeyAddr != address(0), "contract already added");
    //     honeyAddr = _honeyAddr;
    //     honey = HONEY(_honeyAddr);
    // }

    // function addTraitsContract(address _traitsAddr) external onlyOwner {
    //     require(honeyAddr != address(0), "contract already added");
    //     traitsAddr = _traitsAddr;
    //     traits = ITraits(_traitsAddr);
    // }


  // **********************************************************************************************************************************
  // **********************************************************************************************************************************
  // **********************************************************************************************************************************
  // Unfinished code using Chainlink VRF
  // This entire function can be removed.  
  // You just need the LINK balance check and the requestId = requestRandomness(vrfKeyHash, vrfFee); to be somewhere in your logic. 
  // It should go where ever you want to request the random number from Chainlink VRF.  I believe this should happen during "Step 1", the "Pay" step.
  function getRandomNumber() public returns (bytes32 requestId) {
      require(LINK.balanceOf(address(this)) >= vrfFee, "Not enough LINK");
      requestId = requestRandomness(vrfKeyHash, vrfFee);
      return requestId;
  }

  // Unfinished code using Chainlink VRF
  // This function needs to be in the contract.  Do not change the name of the function.
  // This is the function that Chainlink will send the random number back to.
  // This is where you would save the random number to the contract however you need to, to later be used when you do the mint/reveal.  This is "Step 2"
  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
      vrfRandomnessRequestResult[requestId] = randomness;
      vrfRandomResult = randomness;
  }
  // **********************************************************************************************************************************
  // **********************************************************************************************************************************
  // **********************************************************************************************************************************

 
  function mint(uint256 amount, bool stake) external payable whenNotPaused {
    require(tx.origin == _msgSender(), "Only EOA");
    require(minted + amount <= MAX_TOKENS, "No supply");
    require(amount > 0, "You can't mint zero");
    if (minted < PAID_TOKENS) {
      require(minted + amount <= PAID_TOKENS, "None left, try OpenSea");
      require(amount * MINT_PRICE == msg.value, "Need to pay to play");
    } else {
      require(msg.value == 0);
    }
//add the logic honey tokens to mint cubs based on price
    uint256 totalHoneyCost = 0;
    uint16[] memory tokenIds = stake ? new uint16[](amount) : new uint16[](0);
    uint256 seed;
    for (uint i = 0; i < amount; i++) {
      minted++;
      seed = random(minted);
      generate(minted, seed);
      address recipient = selectRecipient(seed);
      if (!stake || recipient != _msgSender()) {
        _safeMint(recipient, minted);
        emit saleMade(msg.sender, stake, amount);
      } else {
        _safeMint(address(forest), minted);
        tokenIds[i] = minted;
      }
      totalHoneyCost += mintCost(minted);
      emit saleMade(msg.sender, stake, amount);
    }
    
    if (totalHoneyCost > 0) honey.burn(_msgSender(), totalHoneyCost);
    if (stake) forest.addManyToForestAndPack(_msgSender(), tokenIds);
    emit saleMade(msg.sender, stake, amount);
  }

  /** 
   * the first 20% are paid in ETH
   * the next 20% are 25,000 $HONEY
   * the next 15% are 50,000 $HONEY
   * the final 20% are 80000 $HONEY
   * @param tokenId the ID to check the cost of to mint
   * @return the cost of the given token ID
   */
  function mintCost(uint256 tokenId) public view returns (uint256) {
    if (tokenId <= PAID_TOKENS) return 0;
    if (tokenId <= MAX_TOKENS * 3 / 5) return 25000 ether;
    if (tokenId <= MAX_TOKENS *  9 / 10) return 50000 ether;
    if (tokenId > MAX_TOKENS *  9 / 10) return 75000 ether;
    return 100000 ether;
  }

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    // Hardcode the Foresr's approval so that users don't have to waste gas approving
    if (_msgSender() != address(forest))
      require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: not owner nor approved");
    _transfer(from, to, tokenId);
  }

  /** INTERNAL */

  /**
   * generates traits for a specific token, checking to make sure it's unique
   * @param tokenId the id of the token to generate traits for
   * @param seed a pseudorandom 256 bit number to derive traits from
   * @return t - a struct of traits for the given token ID
   */
  function generate(uint256 tokenId, uint256 seed) internal returns (BeesCubs memory t) {
    t = selectTraits(seed);
    if (existingCombinations[structToHash(t)] == 0) {
      tokenTraits[tokenId] = t;
      existingCombinations[structToHash(t)] = tokenId;
      return t;
    }
    return generate(tokenId, random(seed));
  }

  /**
   * uses A.J. Walker's Alias algorithm for O(1) rarity table lookup
   * ensuring O(1) instead of O(n) reduces mint cost by more than 50%
   * probability & alias tables are generated off-chain beforehand
   * @param seed portion of the 256 bit seed to remove trait correlation
   * @param traitType the trait type to select a trait for 
   * @return the ID of the randomly selected trait
   */
  function selectTrait(uint16 seed, uint8 traitType) internal view returns (uint8) {
    uint8 trait = uint8(seed) % uint8(rarities[traitType].length);
    if (seed >> 8 < rarities[traitType][trait]) return trait;
    return aliases[traitType][trait];
  }

  /**
   * the first 20% (ETH purchases) go to the minter
   * the remaining 80% have a 10% chance to be given to a random staked bear
   * @param seed a random value to select a recipient from
   * @return the address of the recipient (either the minter or the bear thief's owner)
   */
  function selectRecipient(uint256 seed) internal view returns (address) {
    if (minted <= PAID_TOKENS || ((seed >> 245) % 10) != 0) return _msgSender(); // top 10 bits haven't been used
    address thief = forest.randomBearOwner(seed >> 144); // 144 bits reserved for trait selection
    if (thief == address(0x0)) return _msgSender();
    return thief;
  }

  /**
   * selects the species and all of its traits based on the seed value
   * @param seed a pseudorandom 256 bit number to derive traits from
   * @return t -  a struct of randomly selected traits
   */

  function selectTraits(uint256 seed) internal view returns (BeesCubs memory t) {    
    t.isBee = (seed & 0xFFFF) % 10 != 0;
	if (t.isBee) {
		t.background = selectTrait(uint16(seed & 0xFFFF), 0);
		seed >>= 16;
		t.upperBody = selectTrait(uint16(seed & 0xFFFF), 2);
		seed >>= 16;
		t.body = selectTrait(uint16(seed & 0xFFFF), 3) ;
		seed >>= 16;
		t.mouth = selectTrait(uint16(seed & 0xFFFF), 4) ;
		seed >>= 16;
		t.eyes = selectTrait(uint16(seed & 0xFFFF), 6);
		seed >>= 16;
		t.face = selectTrait(uint16(seed & 0xFFFF), 7);
		seed >>= 16;
		t.head = selectTrait(uint16(seed & 0xFFFF), 8);

	} else {
		t.background = selectTrait(uint16(seed & 0xFFFF), 10);
		seed >>= 16;
		t.body = selectTrait(uint16(seed & 0xFFFF), 12);
		seed >>= 16;
		t.upperBody = selectTrait(uint16(seed & 0xFFFF), 13);
		seed >>= 16;
		t.head = selectTrait(uint16(seed & 0xFFFF), 14);
		seed >>= 16;
		t.ears = selectTrait(uint16(seed & 0xFFFF), 15);
		seed >>= 16;
		t.eyes = selectTrait(uint16(seed & 0xFFFF), 16);
		seed >>= 16;
		t.face = selectTrait(uint16(seed & 0xFFFF), 17);
		seed >>= 16;
		t.mouth = selectTrait(uint16(seed & 0xFFFF), 18);
		seed >>= 16;
		t.senseIndex = selectTrait(uint16(seed & 0xFFFF), 19);
	}	
  }

  /**
   * converts a struct to a 256 bit hash to check for uniqueness
   * @param s the struct to pack into a hash
   * @return the 256 bit hash of the struct
   */
  function structToHash(BeesCubs memory s) internal pure returns (uint256) {
    return uint256(keccak256(
      abi.encodePacked(
        s.isBee,
        s.background,
        s.body,
        s.eyes,
        s.face,
        s.head,
        s.mouth,
        s.upperBody,
        s.senseIndex
      )
    ));
  }

  /**
   * generates a pseudorandom number
   * @param seed a value ensure different outcomes for different sources in the same block
   * @return a pseudorandom value
   */
  function random(uint256 seed) internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(
      tx.origin,
      blockhash(block.number - 1),
      block.timestamp,
      seed
    )));
  }

  /** READ */

  function getTokenTraits(uint256 tokenId) external view override returns (BeesCubs memory) {
    return tokenTraits[tokenId];
  }

  function getPaidTokens() external view override returns (uint256) {
    return PAID_TOKENS;
  }

  /** ADMIN */

  /**
   * called after deployment so that the contract can get random bear  thieves
   * @param _forest the address of the forest
   */
  function setForest(address _forest) external onlyOwner {
    forest = IForest(_forest);
  }

    /**
     * allows owner to withdraw funds from minting
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

  /**
   * updates the number of tokens for sale
  //  */
  // function setPaidTokens(uint256 _paidTokens) external onlyOwner {
  //   PAID_TOKENS = _paidTokens;
  // }

  /**
   * enables owner to pause / unpause minting
   */
  function setPaused(bool _paused) external onlyOwner {
    if (_paused) _pause();
    else _unpause();
  }

  /** RENDER */

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    return traits.tokenURI(tokenId);
  }
}

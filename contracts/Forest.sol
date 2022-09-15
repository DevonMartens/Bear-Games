// SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;

import "./interfaces/IERC721Receiver.sol";
import "./Pausable.sol";
import "./Bear.sol";
import "./Honey.sol";
import "./ReentrancyGuard.sol";

//do we need safemath here?

contract Forest is Ownable, IERC721Receiver, Pausable, ReentrancyGuard {
  // maximum sense score for a bear
  uint8 public constant MAX_SENSE = 8;

  // struct to store a stake's token, owner, and earning values
  struct Stake {
    uint16 tokenId;
    uint80 value;
    address owner;
  }

  event TokenStaked(address owner, uint256 tokenId, uint256 value);
  event TokensStaked(address owner, uint16[], uint256 value);
  event BeeClaimed(uint256 tokenId, uint256 earned, bool unstaked);
  event BearClaimed(uint256 tokenId, uint256 earned, bool unstaked);

  // reference to the Bear NFT contract
  Bear beear;
  // reference to the $HONEY contract for minting $HONEY earnings
  HONEY honey;

  // maps tokenId to stake
  mapping(uint256 => Stake) public forest; 
  // maps sense to all Bear stakes with that sense
  mapping(uint256 => Stake[]) public pack; 
  // tracks location of each Bear in Pack
  mapping(uint256 => uint256) public packIndices; 
  // total sense scores staked
  uint256 public totalSenseStaked = 0; 
  // any rewards distributed when no bears are staked
  uint256 public unaccountedRewards = 0; 
  // amount of $Honey due for each sense point staked
  uint256 public honeyPerSense = 0; 

  // bee earn 10000 $Honey per day
  uint256 public constant DAILY_HONEY_RATE = 10000 ether;
  // bee must have 2 days worth of $Honey to unstake or else it's too cold

  // change back to 2 days before deploying!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  uint256 public constant MINIMUM_TO_EXIT = 1 minutes;
  //cub take a 20% tax on all $Honeyclaimed
  uint256 public constant HONEY_CLAIM_TAX_PERCENTAGE = 20;
  // there will only ever be (roughly) 45000000000 billion $COMB earned through staking
  uint256 public constant MAXIMUM_GLOBAL_HONEY = 45000000000 ether;

  // amount of $HONEY earned so far
  uint256 public totalHoneyEarned;
  // number of Bees staked in the Forest
  uint256 public totalBeesStaked;
  // the last time$HONEY was claimed
  uint256 public lastClaimTimestamp;

  // emergency rescue to allow unstaking without any checks but without $HONEY
  bool public rescueEnabled = false;
  /**
   * @param _beear reference to the bear NFT contract
   * @param _honey reference to the $Honey token
   */
  constructor(address payable _beear, address _honey) { 
    beear = Bear(_beear);
    honey = HONEY(_honey);
  }

  /** STAKING */

  /**
   * adds Bee and Bear to the Forst and Pack
   * @param account the address of the staker
   * @param tokenIds the IDs of the Bee and Bear to stake
   */
  function addManyToForestAndPack(address account, uint16[] calldata tokenIds) external {
    require(account == _msgSender() || _msgSender() == address(beear), "You can't give away those tokens, careful");
    for (uint i = 0; i < tokenIds.length; i++) {
      if (_msgSender() != address(beear)) { // dont do this step if its a mint + stake
        require(beear.ownerOf(tokenIds[i]) == _msgSender(), "Please don't try to take tokens");
        beear.transferFrom(_msgSender(), address(this), tokenIds[i]);
      } else if (tokenIds[i] == 0) {
        continue; // there may be gaps in the array for stolen tokens
      }

      if (isBee(tokenIds[i])) {
        _addBeeToForest(account, tokenIds[i]);
        emit TokensStaked(account, tokenIds, block.timestamp);
      }
      else 
        _addBearToPack(account, tokenIds[i]);
        emit TokensStaked(account, tokenIds, block.timestamp);
    }
  }

  /**
   * adds a single Bee to the Forest
   * @param account the address of the staker
   * @param tokenId the ID of the Bee to add to the Forst
   */
  function _addBeeToForest(address account, uint256 tokenId) internal whenNotPaused _updateEarnings {
    forest[tokenId] = Stake({
      owner: account,
      tokenId: uint16(tokenId),
      value: uint80(block.timestamp)
    });
    totalBeesStaked += 1;
    emit TokenStaked(account, tokenId, block.timestamp);
  }

  /**
   * adds a single Bear to the Pack
   * @param account the address of the staker
   * @param tokenId the ID of the Bear to add to the Pack
   */
  function _addBearToPack(address account, uint256 tokenId) internal {
    uint256 sense = _senseForBear(tokenId);
    totalSenseStaked += sense; // Portion of earnings ranges from 8 to 5
    packIndices[tokenId] = pack[sense].length; // Store the location of the bear in the Pack
    pack[sense].push(Stake({
      owner: account,
      tokenId: uint16(tokenId),
      value: uint80(honeyPerSense)
    })); // Add the bear to the Pack
    emit TokenStaked(account, tokenId, honeyPerSense);
  }

  /** CLAIMING / UNSTAKING */

  /**
   * realize $Honey earnings and optionally unstake tokens from the forest / Pack
   * to unstake a Bee it will require it has 2 days worth of $HONEY unclaimed
   * @param tokenIds the IDs of the tokens to claim earnings from
   * @param unstake whether or not to unstake ALL of the tokens listed in tokenIds
   */
  function claimManyFromForestAndPack(uint16[] calldata tokenIds, bool unstake) external whenNotPaused _updateEarnings {
    uint256 owed = 0;
    for (uint i = 0; i < tokenIds.length; i++) {
      if (isBee(tokenIds[i]))
        owed = owed += _claimBeeFromForest(tokenIds[i], unstake);
      else
        owed = owed += _claimBearFromPack(tokenIds[i], unstake);
    }
    if (owed == 0) return;
    honey.mint(_msgSender(), owed);
  }

  /**
   * realize $HONEY earnings for a single Bee and optionally unstake it
   * if not unstaking, pay a 20% tax to the staked Bears
   * if unstaking, there is a 50% chance all $HONEY is stolen
   * @param tokenId the ID of the Bee to claim earnings from
   * @param unstake whether or not to unstake the Bee
   * @return owed - the amount of $Honey earned
   */
  function _claimBeeFromForest(uint256 tokenId, bool unstake) internal nonReentrant returns (uint256 owed) {
    Stake memory stake = forest[tokenId];
    require(stake.owner == _msgSender(), "That's actually not yours");
    require(!(unstake && block.timestamp - stake.value < MINIMUM_TO_EXIT), "GONNA BE COLD WITHOUT TWO DAY'S HONEY");
    if (totalHoneyEarned < MAXIMUM_GLOBAL_HONEY) {
      owed = (block.timestamp - stake.value) * DAILY_HONEY_RATE / 1 days;
    } else if (stake.value > lastClaimTimestamp) {
      owed = 0; // $HONEY production stopped already
    } else {
      owed = (lastClaimTimestamp - stake.value) * DAILY_HONEY_RATE / 1 days; // stop earning additional $HONEY if it's all been earned
    }
    if (unstake) {
      if (random(tokenId) & 1 == 1) { // 50% chance of all $HONEY stolen
        _payBearTax(owed);
        owed = 0;
      }
      delete forest[tokenId];
      totalBeesStaked -= 1;
      beear.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Bee
    } else {
      _payBearTax(owed * HONEY_CLAIM_TAX_PERCENTAGE / 100); // percentage tax to staked cubs
      owed = owed * (100 - HONEY_CLAIM_TAX_PERCENTAGE) / 100; // remainder goes to Bee owner
      forest[tokenId] = Stake({
        owner: _msgSender(),
        tokenId: uint16(tokenId),
        value: uint80(block.timestamp)
      }); // reset stake
    }
    emit BeeClaimed(tokenId, owed, unstake);
  }

  /**
   * realize $HONEY earnings for a single Bear and optionally unstake it
   * Bears earn $HONEY proportional to their Sense rank
   * @param tokenId the ID of the Bear to claim earnings from
   * @param unstake whether or not to unstake the Bear
   * @return owed - the amount of $HONEY earned
   */
  function _claimBearFromPack(uint256 tokenId, bool unstake) internal nonReentrant returns (uint256 owed) {
    require(beear.ownerOf(tokenId) == address(this), "You are out of the forrest. So you were never in.");
    uint256 sense = _senseForBear(tokenId);
    Stake memory stake = pack[sense][packIndices[tokenId]];
    require(stake.owner == _msgSender(), "No stealing please");
    owed = (sense) * (honeyPerSense - stake.value); // Calculate portion of tokens based on Sense
    if (unstake) {
      totalSenseStaked -= sense; // Remove Sense from total staked
      Stake memory lastStake = pack[sense][pack[sense].length - 1];
      pack[sense][packIndices[tokenId]] = lastStake; // Shuffle last Bear to current position
      packIndices[lastStake.tokenId] = packIndices[tokenId];
      pack[sense].pop(); // Remove duplicate
      delete packIndices[tokenId]; // Delete old mapping
      beear.safeTransferFrom(address(this), _msgSender(), tokenId, "No stealing please"); // Send back Bear
    } else {
      pack[sense][packIndices[tokenId]] = Stake({
        owner: _msgSender(),
        tokenId: uint16(tokenId),
        value: uint80(honeyPerSense)
      }); // reset stake
    }
    emit BearClaimed(tokenId, owed, unstake);
  }

  /**
   * emergency unstake tokens
   * @param tokenIds the IDs of the tokens to claim earnings from
   */
  function rescue(uint256[] calldata tokenIds) external nonReentrant {
    require(rescueEnabled, "RESCUE DISABLED");
    uint256 tokenId;
    Stake memory stake;
    Stake memory lastStake;
    uint256 sense;
    for (uint i = 0; i < tokenIds.length; i++) {
      tokenId = tokenIds[i];
      if (isBee(tokenId)) {
        stake = forest[tokenId];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        delete forest[tokenId];
        totalBeesStaked -= 1;
         beear.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // send back Bee
        emit BeeClaimed(tokenId, 0, true);
      } else {
        sense = _senseForBear(tokenId);
        stake = pack[sense][packIndices[tokenId]];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        totalSenseStaked -= sense; // Remove Sense from total staked
        lastStake = pack[sense][pack[sense].length - 1];
        pack[sense][packIndices[tokenId]] = lastStake; // Shuffle last Bear to current position
        packIndices[lastStake.tokenId] = packIndices[tokenId];
        pack[sense].pop(); // Remove duplicate
        delete packIndices[tokenId]; // Delete old mapping
        beear.safeTransferFrom(address(this), _msgSender(), tokenId, ""); // Send back Bear
        emit BearClaimed(tokenId, 0, true);
      }
    }
  }

  /** ACCOUNTING */

  /** 
   * add $HONEY to claimable pot for the Pack
   * @param amount $HONEY to add to the pot
   */
  function _payBearTax(uint256 amount) internal {
    if (totalSenseStaked == 0) { // if there's no staked bears
      unaccountedRewards += amount; // keep track of $HONEY due to bears
      return;
    }
    // makes sure to include any unaccounted $HONEY
    honeyPerSense += (amount + unaccountedRewards) / totalSenseStaked;
    unaccountedRewards = 0;
  }

  /**
   * tracks $HONEY earnings to ensure it stops once 2.4 billion is eclipsed
   */
  modifier _updateEarnings() {
    if (totalHoneyEarned < MAXIMUM_GLOBAL_HONEY) {
      totalHoneyEarned += 
        (block.timestamp - lastClaimTimestamp)
        * totalBeesStaked
        * DAILY_HONEY_RATE / 1 days; 
      lastClaimTimestamp = block.timestamp;
    }
    _;
  }

  /** ADMIN */

  /**
   * allows owner to enable "rescue mode"
   * simplifies accounting, prioritizes tokens out in emergency
   */
  function setRescueEnabled(bool _enabled) external onlyOwner {
    rescueEnabled = _enabled;
  }

  /**
   * enables owner to pause / unpause minting
   */
  function setPaused(bool _paused) external onlyOwner {
    if (_paused) _pause();
    else _unpause();
  }

  /** READ ONLY */

  /**
   * checks if a token is a Bee
   * @param tokenId the ID of the token to check
   * @return bee - whether or not a token is a Bee
   */
  function isBee(uint256 tokenId) public view returns (bool bee) {
    (bee, , , , , , , , , , ) = beear.tokenTraits(tokenId);
  }

  /**
   * gets the sense score for a Cub
   * @param tokenId the ID of the Cub to get the sense score for
   * @return the sense score of the Cub (5-8)
   */
  function _senseForBear(uint256 tokenId) internal view returns (uint8) {
    ( , , , , , , , , , , uint8 senseIndex) = beear.tokenTraits(tokenId);
    return MAX_SENSE - senseIndex; // sense index is 0-3
  }

  /**
   * chooses a random Bear thief when a newly minted token is stolen
   * @param seed a random value to choose a Bear from
   * @return the owner of the randomly selected Bear thief
   */
  function randomBearOwner(uint256 seed) external view returns (address) {
    if (totalSenseStaked == 0) return address(0x0);
    uint256 bucket = (seed & 0xFFFFFFFF) % totalSenseStaked; // choose a value from 0 to total sense staked
    uint256 cumulative;
    seed >>= 32;
    // loop through each bucket of Bears with the same sense score
    for (uint i = MAX_SENSE - 3; i <= MAX_SENSE; i++) {
      cumulative += pack[i].length * i;
      // if the value is not inside of that bucket, keep going
      if (bucket >= cumulative) continue;
      // get the address of a random Cub with that sense score
      return pack[i][seed % pack[i].length].owner;
    }
    return address(0x0);
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

  function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      require(from == address(0x0), "Cannot send tokens to Forrest directly");
      return IERC721Receiver.onERC721Received.selector;
    }

  
}
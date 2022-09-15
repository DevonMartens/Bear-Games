## RED:
<section style="color: red;">
Traits.base64(bytes) (contracts/traits.sol#196-248) contains an incorrect shift operation: mstore(uint256,uint256)(resultPtr_base64_asm_0 - 2,0x3d3d << 240) (contracts/traits.sol#243)<br />
Traits.base64(bytes) (contracts/traits.sol#196-248) contains an incorrect shift operation: mstore(uint256,uint256)(resultPtr_base64_asm_0 - 1,0x3d << 248) (contracts/traits.sol#244)<br />
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#shift-parameter-mixup
<br /><br />
Bear.selectTrait(uint16,uint8) (contracts/Bear.sol#253-257) uses a weak PRNG: "trait = uint8(seed) % uint8(rarities[traitType].length) (contracts/Bear.sol#254)" <br />
Bear.selectRecipient(uint256) (contracts/Bear.sol#265-270) uses a weak PRNG: "minted <= PAID_TOKENS || ((seed >> 245) % 10) != 0 (contracts/Bear.sol#266)" <br />
Bear.selectTraits(uint256) (contracts/Bear.sol#277-299) uses a weak PRNG: "t.isBee = (seed & 0xFFFF) % 10 != 0 (contracts/Bear.sol#278)" <br />
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#weak-PRNG
</section>

## YELLOW:
<section style="color: yellow;">

ERC721._checkOnERC721Received(address,address,uint256,bytes) (contracts/ERC721.sol#369-390) ignores return value by IERC721Receiver(to).onERC721Received(_msgSender(),from,tokenId,_data) (contracts/ERC721.sol#376-386)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return
<br /><br />
Traits.base64(bytes) (contracts/traits.sol#196-248) performs a multiplication on the result of a division:
	-encodedLen = 4 * ((data.length + 2) / 3) (contracts/traits.sol#203)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#divide-before-multiply
<br /><br />
Forest._claimBeeFromForest(uint256,bool) (contracts/Forest.sol#164-193) performs a multiplication on the result of a division:<br />
	-owed = (block.timestamp - stake.value) * DAILY_HONEY_RATE / 86400 (contracts/Forest.sol#169)<br />
	-_payBearTax(owed * HONEY_CLAIM_TAX_PERCENTAGE / 100) (contracts/Forest.sol#184)<br />
Forest._claimBeeFromForest(uint256,bool) (contracts/Forest.sol#164-193) performs a multiplication on the result of a division:<br />
	-owed = (block.timestamp - stake.value) * DAILY_HONEY_RATE / 86400 (contracts/Forest.sol#169)<br />
	-owed = owed * (100 - HONEY_CLAIM_TAX_PERCENTAGE) / 100 (contracts/Forest.sol#185)<br />
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#divide-before-multiply<br />
<br />
ERC721Enumerable._beforeTokenTransfer(address,address,uint256) (contracts/ERC721Enumerable.sol#71-88) uses a dangerous strict equality:<br />
	- from == address(0) (contracts/ERC721Enumerable.sol#78)<br />
ERC721Enumerable._beforeTokenTransfer(address,address,uint256) (contracts/ERC721Enumerable.sol#71-88) uses a dangerous strict equality:<br />
	- to == address(0) (contracts/ERC721Enumerable.sol#83)<br />
ERC721._isApprovedOrOwner(address,uint256) (contracts/ERC721.sol#234-238) uses a dangerous strict equality:<br />
	- (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner,spender)) (contracts/ERC721.sol#237)<br />
ERC721._transfer(address,address,uint256) (contracts/ERC721.sol#329-347) uses a dangerous strict equality:<br />
	- require(bool,string)(ERC721.ownerOf(tokenId) == from,ERC721: transfer of token that is not own) (contracts/ERC721.sol#334)<br />
ERC721.approve(address,uint256) (contracts/ERC721.sol#111-121) uses a dangerous strict equality:<br />
	- require(bool,string)(_msgSender() == owner || isApprovedForAll(owner,_msgSender()),ERC721: approve caller is not owner nor approved for all) (contracts/ERC721.sol#115-118)<br />
Bear.selectRecipient(uint256) (contracts/Bear.sol#265-270) uses a dangerous strict equality:<br />
	- thief == address(0x0) (contracts/Bear.sol#268)<br />
Forest._claimBeeFromForest(uint256,bool) (contracts/Forest.sol#164-193) uses a dangerous strict equality:<br />
	- require(bool,string)(stake.owner == _msgSender(),That's actually not yours) (contracts/Forest.sol#166)<br />
Forest._claimBeeFromForest(uint256,bool) (contracts/Forest.sol#164-193) uses a dangerous strict equality:<br />
	- random(tokenId) & 1 == 1 (contracts/Forest.sol#176)<br />
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-strict-equalities<br />
<br /><br />
Bear.mint(uint256,bool) (contracts/Bear.sol#165-198) uses tx.origin for authorization: require(bool,string)(tx.origin == _msgSender(),Only EOA) (contracts/Bear.sol#166)<br />
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-usage-of-txorigin
<br /><br />
Forest.randomBearOwner(uint256).cumulative (contracts/Forest.sol#338) is a local variable never initialized<br />
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#uninitialized-local-variables
<br /><br />
ERC721._checkOnERC721Received(address,address,uint256,bytes) (contracts/ERC721.sol#369-390) ignores return value by IERC721Receiver(to).onERC721Received(_msgSender(),from,tokenId,_data) (contracts/ERC721.sol#376-386)<br />
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return<br />
</section>
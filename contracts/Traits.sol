// SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./Strings.sol";
import "./interfaces/ITraits.sol";
import "./interfaces/IBear.sol";
import { Base64 } from "./libraries/Base64.sol";

contract Traits is Ownable, ITraits {

  using Strings for uint256;

  // struct to store each trait's data for metadata and rendering
  struct Trait {
    string name;
    string png;
  }

  // mapping from trait type (index) to its name
  string[9] _traitTypes = [
    "Background",
    "Body",
    "Ears",
    "Eyes",
    "Face",
    "Head",
    "Mouth",
    "Wings",
    "Neck"
  ];
  // storage of each traits name and base64 PNG data
  mapping(uint8 => mapping(uint8 => Trait)) public traitData;
  // mapping from senseIndex to its score
  string[4] _senses = [
    "8",
    "7",
    "6",
    "5"
  ];

  IBear public beear;

  constructor() {}

  /** ADMIN */

  function setBeear(address _beear) external onlyOwner {
     beear = IBear(_beear);
  }

  /**
   * administrative to upload the names and images associated with each trait
   * @param traitType the trait type to upload the traits for (see traitTypes for a mapping)
   * @param traits the names and base64 encoded PNGs for each trait
   */
  function uploadTraits(uint8 traitType, uint8[] calldata traitIds, Trait[] calldata traits) external onlyOwner {
    require(traitIds.length == traits.length, "Mismatched inputs");
    for (uint i = 0; i < traits.length; i++) {
      traitData[traitType][traitIds[i]] = Trait(
        traits[i].name,
        traits[i].png
      );
    }
  }

  /** RENDER */

  /**
   * generates an <image> element using base64 encoded PNGs
   * @param trait the trait storing the PNG data
   * @return the <image> element
   */
  function drawTrait(Trait memory trait) internal pure returns (string memory) {
    return string(abi.encodePacked(
      '<image x="4" y="4" width="32" height="32" image-rendering="pixelated" preserveAspectRatio="xMidYMid meet" xlink:href="data:image/png;base64,',
      trait.png,
      '"/>'
    ));
  }

  /**
   * generates an entire SVG by composing multiple <image> elements of PNGs
   * @param tokenId the ID of the token to generate an SVG for
   * @return a valid SVG of the bees / cubs
   */
  function drawSVG(uint256 tokenId) public view returns (string memory) {
    IBear.BeesCubs memory s = beear.getTokenTraits(tokenId);
	string memory svgString;
	if (s.isBee) {
		svgString = string(abi.encodePacked(
			drawTrait(traitData[0][s.background]),
			drawTrait(traitData[1][0]),
			drawTrait(traitData[2][s.upperBody]),
			drawTrait(traitData[3][s.body]),
			drawTrait(traitData[4][s.mouth]),
			drawTrait(traitData[6][s.eyes]),
			drawTrait(traitData[7][s.face]),
			drawTrait(traitData[8][s.head])
		));
	} else {
		svgString = string(abi.encodePacked(
			drawTrait(traitData[10][s.background]),
			drawTrait(traitData[11][0]),
			drawTrait(traitData[12][s.body]),
			drawTrait(traitData[13][s.upperBody]),
			drawTrait(traitData[14][s.head]),
			drawTrait(traitData[15][s.ears]),
			drawTrait(traitData[16][s.eyes]),
			drawTrait(traitData[17][s.face]),
			drawTrait(traitData[18][s.mouth])
		));
	}
    return string(abi.encodePacked(
      '<svg id="beear" width="100%" height="100%" version="1.1" viewBox="0 0 40 40" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
      svgString,
      "</svg>"
    ));
  }

  /**
   * generates an attribute for the attributes array in the ERC721 metadata standard
   * @param traitType the trait type to reference as the metadata key
   * @param value the token's trait associated with the key
   * @return a JSON dictionary for the single attribute
   */
  function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
    return string(abi.encodePacked(
      '{"trait_type":"',
      traitType,
      '","value":"',
      value,
      '"}'
    ));
  }

  /**
   * generates an array composed of all the individual traits and values
   * @param tokenId the ID of the token to compose the metadata for
   * @return a JSON array of all of the attributes for given token ID
   */
  function compileAttributes(uint256 tokenId) public view returns (string memory) {
    IBear.BeesCubs memory s = beear.getTokenTraits(tokenId);
    string memory traits;
    if (s.isBee) {
      traits = string(abi.encodePacked(
        attributeForTypeAndValue(_traitTypes[0], traitData[0][s.background].name),',',
        attributeForTypeAndValue(_traitTypes[1], traitData[3][s.body].name),',',
        attributeForTypeAndValue(_traitTypes[3], traitData[6][s.eyes].name),',',
        attributeForTypeAndValue(_traitTypes[4], traitData[7][s.face].name),',',
        attributeForTypeAndValue(_traitTypes[5], traitData[8][s.head].name),',',
        attributeForTypeAndValue(_traitTypes[6], traitData[4][s.mouth].name),',',
        attributeForTypeAndValue(_traitTypes[7], traitData[2][s.upperBody].name),','
      ));
    } else {
      traits = string(abi.encodePacked(
        attributeForTypeAndValue(_traitTypes[0], traitData[10][s.background].name),',',
        attributeForTypeAndValue(_traitTypes[1], traitData[12][s.body].name),',',
        attributeForTypeAndValue(_traitTypes[2], traitData[15][s.ears].name),',',
        attributeForTypeAndValue(_traitTypes[3], traitData[16][s.eyes].name),',',
        attributeForTypeAndValue(_traitTypes[4], traitData[17][s.face].name),',',
        attributeForTypeAndValue(_traitTypes[5], traitData[14][s.head].name),',',
        attributeForTypeAndValue(_traitTypes[6], traitData[18][s.mouth].name),',',
        attributeForTypeAndValue(_traitTypes[8], traitData[13][s.upperBody].name),',',
        attributeForTypeAndValue("Sense Score", _senses[s.senseIndex]),','
      ));
    }
    return string(abi.encodePacked(
      '[',
      traits,
      '{"trait_type":"Generation","value":',
      tokenId <= beear.getPaidTokens() ? '"Gen 0"' : '"Gen 1"',
      '},{"trait_type":"Type","value":',
      s.isBee ? '"Bee"' : '"Bear"',
      '}]'
    ));
  }

  /**
   * generates a base64 encoded metadata response without referencing off-chain content
   * @param tokenId the ID of the token to generate the metadata for
   * @return a base64 encoded JSON dictionary of the token's metadata and SVG
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    IBear.BeesCubs memory s = beear.getTokenTraits(tokenId);

    string memory metadata = string(abi.encodePacked(
      '{"name": "',
      s.isBee ? 'Bee #' : 'Bear #',
      tokenId.toString(),
      '", "description": "Thousands of Bees and Bears compete in a forest in the metaverse. A tempting prize of $HONEY awaits, with deadly high stakes. All the metadata and images are generated and stored 100% on-chain. No IPFS. NO API. Just the Ethereum blockchain.", "image": "data:image/svg+xml;base64,',
      Base64.encode(bytes(drawSVG(tokenId))),
      '", "attributes":',
      compileAttributes(tokenId),
      "}"
    ));

    return string(abi.encodePacked(
      "data:application/json;base64,",
      Base64.encode(bytes(metadata))
    ));
  }
}
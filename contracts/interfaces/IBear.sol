// SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;

interface IBear {

  // struct to store each token's traits
  struct BeesCubs {
    bool isBee;
	bytes32 requestId;
    uint8 background;
    uint8 body;
    uint8 ears;
    uint8 eyes;
    uint8 face;
    uint8 head;
    uint8 mouth;
    uint8 upperBody;
    uint8 senseIndex;
  }


  function getPaidTokens() external view returns (uint256);
  function getTokenTraits(uint256 tokenId) external view returns (BeesCubs memory);
}
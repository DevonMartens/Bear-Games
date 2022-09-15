// SPDX-License-Identifier: ISC

pragma solidity ^0.8.0;
import "./ERC20.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";



contract HONEY is ERC20, Ownable {
  //variable false sets true after surprisemint
  bool didWeGetTheReserves = false;
  //mint and butrn events
  event combBurn(address from, uint256 amount);
  event combMint(address to, uint256 amount);
  // a mapping from an address to whether or not it can mint / burn
  mapping(address => bool) controllers;
  // mint a set amount to owner on deployment 
  // boolean to monitor reserves 
  constructor() ERC20("COMBS", "CMB") { 

  }
  

  /**
   * mints $HONEY to a recipient
   * @param to the recipient of the $HONEY
   * @param amount the amount of $HONEY to mint
   */
  function mint(address to, uint256 amount) external {
    require(controllers[msg.sender], "Only controllers can mint");
    _mint(to, amount);
    emit combMint(to, amount);
  }
//only ever called once for community surprise
  function Surprisemint(bool _didWeGetTheReserves) public onlyOwner {
    require(_didWeGetTheReserves = false, "you minted you");
            _mint(msg.sender, 18000000000);
            _didWeGetTheReserves = true;
    }
  /**
   * burns $HONEY from a holder
   * @param from the holder of the $HONEY
   * @param amount the amount of $HONEY to burn
   */
  function burn(address from, uint256 amount) external {
    require(controllers[msg.sender], "Only controllers can burn");
    _burn(from, amount);
    emit combBurn(from, amount);
  }

  /**
   * enables an address to mint / burn
   * @param controller the address to enable
   */
  function addController(address controller) external onlyOwner {
    controllers[controller] = true;
  }

  /**
   * disables an address from minting / burning
   * @param controller the address to disbale
   */
  function removeController(address controller) external onlyOwner {
    controllers[controller] = false;
  }
}
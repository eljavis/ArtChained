//SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import "../lib/forge-std/src/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

function mint(address to_, uint256 tokenId_) external {
    _mint(to_, tokenId_);
}

}

contract NFTMarketplaceTest is Test {

    function setUp() public{
        
    }
}

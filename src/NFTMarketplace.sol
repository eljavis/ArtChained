// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
contract NFTMarketplace is Ownable, ReentrancyGuard {

    struct Listing {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
    }

    mapping (address => mapping(uint256 => Listing)) listing;

    event NFTListed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event NFTCancelled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);
    event NFTSold(address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price);
    

    constructor() Ownable(msg.sender) {
        
    }

//List NFT's
    function listNFT(address nftAddress_, uint256 tokenId_, uint256 price_) external nonReentrant {
        require(price_ > 0, "Price must be greater than 0");
        address owner_ = IERC721(nftAddress_).ownerOf(tokenId_);
        require(owner_ == msg.sender, "Only the owner of the NFT can list it");


        Listing memory listing_ = Listing({
            seller: msg.sender,
            nftAddress: nftAddress_,
            tokenId: tokenId_,
            price: price_
        });

        listing[nftAddress_][tokenId_] = listing_;
        emit NFTListed(msg.sender, nftAddress_, tokenId_, price_);

    }
//Buy NFT's
function buyNFT(address nftAddress_, uint256 tokenId_) external payable nonReentrant {
    Listing memory listing_ = listing[nftAddress_][tokenId_];
    require(listing_.price > 0, "Listing not found");
    require(msg.value == listing_.price, "Incorrect payment amount");

    delete listing[nftAddress_][tokenId_];

    IERC721(nftAddress_).safeTransferFrom(listing_.seller, msg.sender, listing_.tokenId);
    
    (bool success, ) = listing_.seller.call{value: msg.value}("");
    require(success, "Fail");

    emit NFTSold(msg.sender, listing_.seller, listing_.nftAddress, listing_.tokenId, listing_.price);
}

//Cancel List
function cancelList(address nftAddress_, uint256 tokenId_) external nonReentrant {
    Listing memory listing_ = listing[nftAddress_][tokenId_];
    require(listing_.seller == msg.sender, "Only the seller can cancel the list");

    delete listing[nftAddress_][tokenId_];
    emit NFTCancelled(msg.sender, nftAddress_, tokenId_);

}
}
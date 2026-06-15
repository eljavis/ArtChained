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

    
    uint256 public listingFee = 0.01 ether;      // Fixed fee for publishing an NFT
    uint256 public ownerPercentage = 5;          // Percentage that goes to the owner (e.g., 5%)

    mapping (address => mapping(uint256 => Listing)) listing;

    event NFTListed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event NFTCancelled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);
    event NFTSold(address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price);
    
    constructor() Ownable(msg.sender) {
        
    }

    //List NFT's
    function listNFT(address nftAddress_, uint256 tokenId_, uint256 price_) external payable nonReentrant {
        require(msg.value == listingFee, "Incorrect listing fee");
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

        // Send listing fee directly to the contract owner
        if (listingFee > 0) {
            (bool feeSuccess, ) = owner().call{value: msg.value}("");
            require(feeSuccess, "Listing fee transfer failed");
        }

        emit NFTListed(msg.sender, nftAddress_, tokenId_, price_);
    }

    //Buy NFT's
    function buyNFT(address nftAddress_, uint256 tokenId_) external payable nonReentrant {
        Listing memory listing_ = listing[nftAddress_][tokenId_];
        require(listing_.price > 0, "Listing not found");
        require(msg.value == listing_.price, "Incorrect payment amount");

        delete listing[nftAddress_][tokenId_];

        IERC721(nftAddress_).safeTransferFrom(listing_.seller, msg.sender, listing_.tokenId);
        
        // Calculate the percentages of the fee for selling
        uint256 ownerShare = (listing_.price * ownerPercentage) / 100;
        uint256 sellerShare = listing_.price - ownerShare;

        // Send the portion that corresponds to the contract owner.
        if (ownerShare > 0) {
            (bool ownerSuccess, ) = owner().call{value: ownerShare}("");
            require(ownerSuccess, "Owner fee transfer failed");
        }

        // Send the rest to the seller.
        (bool sellerSuccess, ) = listing_.seller.call{value: sellerShare}("");
        require(sellerSuccess, "Fail");

        emit NFTSold(msg.sender, listing_.seller, listing_.nftAddress, listing_.tokenId, listing_.price);
    }

    //Cancel List
    function cancelList(address nftAddress_, uint256 tokenId_) external nonReentrant {
        Listing memory listing_ = listing[nftAddress_][tokenId_];
        require(listing_.seller == msg.sender, "Only the seller can cancel the list");

        delete listing[nftAddress_][tokenId_];
        emit NFTCancelled(msg.sender, nftAddress_, tokenId_);
    }

    //Update Percentage
    function updateOwnerPercentage(uint256 newPercentage_) external onlyOwner {
        require(newPercentage_ <= 100, "Percentage cannot exceed 100");
        ownerPercentage = newPercentage_;
    }

    //Update Fee
    function updateListingFee(uint256 newFee_) external onlyOwner {
        listingFee = newFee_;
    }
}
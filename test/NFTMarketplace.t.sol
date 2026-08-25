//SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import "../lib/forge-std/src/Test.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../src/NFTMarketplace.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("MockNFT", "MNFT") {}

function mint(address to_, uint256 tokenId_) external {
    _mint(to_, tokenId_);
}

}

contract NFTMarketplaceTest is Test {

NFTMarketplace marketplace;
MockNFT nft;
address deployer = vm.addr(1);
address user = vm.addr(2);
address user2 = vm.addr(3);
uint256 tokenId = 0;
uint256 price = 10 ether;
uint256 listingFee = 0.01 ether;
uint256 ownerPercentage = 5;



    function setUp() public{
        vm.startPrank(deployer);
        marketplace = new NFTMarketplace();
        nft = new MockNFT();
        vm.stopPrank();

        vm.startPrank(deployer);
        marketplace.updateListingFee(listingFee);
        marketplace.updateOwnerPercentage(ownerPercentage);
        vm.stopPrank();

        vm.startPrank(user);
        nft.mint(user, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        nft.mint(user2, 1);
        vm.stopPrank();

    }

    function testMintNFT() public view {
        address ownerOf = nft.ownerOf(tokenId);
        assert(ownerOf == user);
    }

    function testShouldRevertIfPriceIsZero() public {
        vm.deal(user, listingFee);
        vm.startPrank(user);
        
        
        vm.expectRevert("Price must be greater than 0");
        marketplace.listNFT{value: listingFee}(address(nft), tokenId, 0);

        vm.stopPrank();
    }

    function testShouldRevertIfNotOwner() public {
        vm.deal(user, listingFee);
        vm.startPrank(user);
        

        vm.expectRevert("Only the owner of the NFT can list it");
        marketplace.listNFT{value: listingFee}(address(nft), 1, 3);

        vm.stopPrank();

    }

    function testListNFTCorrectly() public {
     vm.deal(user, listingFee);
        vm.startPrank(user);
        
        (address sellerBefore,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.listNFT{value: listingFee}(address(nft), tokenId, price);
        (address sellerAfter,,,) = marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);
        vm.stopPrank();   
    }

    function testCancelListShouldRevertIfNotOwner() public {
        vm.deal(user, listingFee);
        vm.startPrank(user);
        
        (address sellerBefore,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.listNFT{value: listingFee}(address(nft), tokenId, 1e18);
        (address sellerAfter,,,) = marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);
        vm.stopPrank(); 

        vm.startPrank(user2);

        vm.expectRevert("Only the seller can cancel the list");
        marketplace.cancelList(address(nft), tokenId);

        vm.stopPrank();
    }

    function testCancelListCorrectly() public {
        vm.deal(user, listingFee);
        vm.startPrank(user);
        
        (address sellerBefore,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.listNFT{value: listingFee}(address(nft), tokenId, 1e18);
        (address sellerAfter,,,) = marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);
        
        marketplace.cancelList(address(nft), tokenId);
        (address sellerAfter2,,,) = marketplace.listing(address(nft), tokenId);

        assert(sellerAfter2 == address(0));
        vm.stopPrank();

    }

    function testCanNotBuyUnlistedNFT() public {
        vm.startPrank(user2);

        vm.expectRevert("Listing not found");
        marketplace.buyNFT(address(nft), tokenId);

        vm.stopPrank();
    }

    function testCanNotBuyWithIncorrectPay() public {
        vm.deal(user, listingFee);
        vm.startPrank(user);
        

        (address sellerBefore,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.listNFT{value: listingFee}(address(nft), tokenId, price);
        (address sellerAfter,,,) = marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);
        vm.stopPrank();  

        vm.startPrank(user2);
        vm.deal(user2, price);
        vm.expectRevert("Incorrect payment amount");
        marketplace.buyNFT{value: price - 1}(address(nft), tokenId);

        vm.stopPrank();
    }

    function testShouldBuyNFTCorrectly() public {
        vm.deal(user, listingFee);
        vm.startPrank(user);
        

        (address sellerBefore,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.listNFT{value: listingFee}(address(nft), tokenId, price);
        (address sellerAfter,,,) = marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);
        nft.approve(address(marketplace), tokenId);
        vm.stopPrank();  

        vm.startPrank(user2);
        vm.deal(user2, price);
        
        (address sellerBefore2,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.buyNFT{value: price}(address(nft), tokenId);
        (address sellerAfter2,,,) = marketplace.listing(address(nft), tokenId);
        assert(sellerBefore2 == user && sellerAfter2 == address(0));

        vm.stopPrank();
    
    }    

    function testTokenWasTransferredCorrectly() public {
    vm.deal(user, listingFee);
        vm.startPrank(user);
        
        (address sellerBefore,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.listNFT{value: listingFee}(address(nft), tokenId, price);
        (address sellerAfter,,,) = marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);
        nft.approve(address(marketplace), tokenId);
        vm.stopPrank();  

        vm.startPrank(user2);
        vm.deal(user2, price);
        
        
        address tokenOwnerBefore = nft.ownerOf(tokenId);
        (address sellerBefore2,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.buyNFT{value: price}(address(nft), tokenId);
        (address sellerAfter2,,,) = marketplace.listing(address(nft), tokenId);
        address tokenOwnerAfter = nft.ownerOf(tokenId);
        

        assert(sellerBefore2 == user && sellerAfter2 == address(0));
        assert(tokenOwnerBefore == user && tokenOwnerAfter == user2);
        

        vm.stopPrank();        
    }  

    function testAllPartsReceivePaymentCorrectly() public {
        vm.deal(user, listingFee);
        vm.startPrank(user);
        
        (address sellerBefore,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.listNFT{value: listingFee}(address(nft), tokenId, price);
        (address sellerAfter,,,) = marketplace.listing(address(nft), tokenId);

        assert(sellerBefore == address(0) && sellerAfter == user);
        nft.approve(address(marketplace), tokenId);
        vm.stopPrank();  

        vm.startPrank(user2);
        vm.deal(user2, price);
        
        uint256 balanceBefore = address(user).balance;
        uint256 contractOwnerBalanceBefore = address(deployer).balance;

        address tokenOwnerBefore = nft.ownerOf(tokenId);
        (address sellerBefore2,,,) = marketplace.listing(address(nft), tokenId);
        marketplace.buyNFT{value: price}(address(nft), tokenId);
        (address sellerAfter2,,,) = marketplace.listing(address(nft), tokenId);
        address tokenOwnerAfter = nft.ownerOf(tokenId);
        uint256 balanceAfter = address(user).balance;
        uint256 contractOwnerBalanceAfter = address(deployer).balance;

        uint256 contractOwnerFee = (price * 5) / 100;            //Contract's owner comission calculation
        uint256 expectedSellerPayout = price - contractOwnerFee;
        
        assert(sellerBefore2 == user && sellerAfter2 == address(0));
        assert(tokenOwnerBefore == user && tokenOwnerAfter == user2);
        assert(balanceAfter == balanceBefore + expectedSellerPayout);
        assert(contractOwnerBalanceAfter == contractOwnerBalanceBefore + contractOwnerFee);

        vm.stopPrank();
    }

    function testRevertUpdateListingFeeIfNotOwner() public {
        vm.startPrank(user);
        
        vm.expectRevert("Only the owner of the contract can update the listing fee");
        marketplace.updateListingFee(listingFee);
        
        vm.stopPrank();
    }

    function testUpdateListingFeeIfOwner() public {
    vm.startPrank(deployer);
    uint256 newTestFee = 0.5 ether; 

    uint256 listingFeeBefore = marketplace.listingFee();
    //Update listing fee 
    marketplace.updateListingFee(newTestFee);
    uint256 listingFeeAfter = marketplace.listingFee();
    
    //Verify listing fee changes correctly
    assert(listingFeeAfter != listingFeeBefore);
    
    vm.stopPrank();
}

function testRevertUpdatePercentageIfExceeds() public {
        vm.startPrank(deployer);
        uint256 newOwnerPercentage = 150; 

        vm.expectRevert("Percentage cannot exceed 100");
        marketplace.updateOwnerPercentage(newOwnerPercentage);
        
        vm.stopPrank();
    }
    
function testRevertUpdatePercentageIfNotOwner() public {
        vm.startPrank(user);
        uint256 newOwnerPercentage = 1; 

        vm.expectRevert("Only the owner of the contract can update his/her own percentage");
        marketplace.updateOwnerPercentage(newOwnerPercentage);
        
        vm.stopPrank();
    }    
}

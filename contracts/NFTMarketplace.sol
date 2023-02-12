//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol"; //helps in testing of contracts to console log contact variables
import "@openzeppelin/contracts/utils/Counters.sol"; //safe and secure implementation of counter
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol"; //an interface,contains functions that help in secure storage of tokenURI
import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; //standard token format by openzeppelin

contract NFTMarketPlace is ERC721URIStorage {
    address payable owner; //the address of the owner who deploys the NFTMarketPlace contract

    using Counters for Counters.Counter; //Counters is a library in which the Counter is a Struct, so here we are trying to define a datatype for all counters that will be used in the contract

    Counters.Counter private _tokenIds; //to keep track of the latest nft minted
    Counters.Counter private _itemsSold; //to keep track of number of nfts sold

    uint256 listPrice = 0.0001 ether; //the price to be paid when listing the nft on th marketplace

    constructor() ERC721("NFTMarketPlace", "NFTM") {
        owner = payable(msg.sender);
    }

    struct ListedToken {
        //structure for the nfts that will be listed on the marketplace
        uint256 tokenId; //token id of the nft
        address payable owner; //owner of the nft
        address payable seller; //seller of the nft
        uint256 price; //price of the nft
        bool currentlyListed; //to specify if the nft is currently listed on the marketplace or not
    }
    mapping(uint256 => ListedToken) private idToListedToken; //mapping of token id counter to listed nft tokens

    //<-------------------Helper Functions----------------------------->

    //function to change the listing fees,can only be called by the owner
    //function should be public so that it can accessed outside the smartcontract
    function updateListPrice(uint256 _listPrice) public payable {
        require(msg.sender == owner, "only owner can update the listing price");
        listPrice = _listPrice;
    }

    //function to know the listprice of the marketplace
    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

    //to get the latest token that has been listed
    function getLatestIdToListedToken()
        public
        view
        returns (ListedToken memory)
    {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    //to retrieve data of the nft using the tokenid
    function getListedForTokenId(uint256 tokenId)
        public
        view
        returns (ListedToken memory)
    {
        return idToListedToken[tokenId];
    }

    //function to get the latest current token id
    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    //<---------------important functions------------------>

    //function to create nft token using the details->the tokenURI and the price to be listed
    //function is made payable so it is able to accept the listprice fees
    function createToken(string memory tokenURI, uint256 price)
        public
        payable
        returns (uint256)
    {
        require(msg.value == listPrice, "Send enough ether to list");
        require(price > 0, "ensure that price is positive value");

        //increment the tokenid count;
        _tokenIds.increment();
        uint256 currentTokenId = _tokenIds.current();
        _safeMint(msg.sender, currentTokenId); //_safeMint ensures that the address is able to accept nft tokens
        _setTokenURI(currentTokenId, tokenURI);
        createListedToken(currentTokenId, price); //to create the token that will be listed on the marketplace

        return currentTokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price) private {
        idToListedToken[tokenId] = ListedToken(
            tokenId,
            payable(address(this)),
            payable(msg.sender),
            price,
            true
        ); //creating the nft token and storing it in the map
        _transfer(msg.sender, address(this), tokenId); //making the smart contract the owner by transferring the ownership
    }

    //function to get all nfts ->returns array of the listed tokens
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint256 nftCount = _tokenIds.current(); //get count of all nfts
        ListedToken[] memory tokens = new ListedToken[](nftCount); //array of type listedToken
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < nftCount; ++i) {
            uint256 currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        return tokens;
    }

    //function to get nfts owned by the user
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        //first all the nfts owned by the user needs to be fetched
        for (uint256 i = 0; i < totalItemCount; ++i) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                itemCount += 1;
            }
        }

        //now an array of the owned Nfts of the user is created
        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint256 i = 0; i < totalItemCount; ++i) {
            if (
                idToListedToken[i + 1].owner == msg.sender ||
                idToListedToken[i + 1].seller == msg.sender
            ) {
                uint256 currentId = i + 1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    //function to purchase the nft by sending the ether price
    function executeSale(uint256 tokenId) public payable {
        uint256 price = idToListedToken[tokenId].price;
        require(
            msg.value == price,
            "please submit the listed price in order to purchase the nft"
        );

        address seller = idToListedToken[tokenId].seller;

        idToListedToken[tokenId].currentlyListed = true;
        idToListedToken[tokenId].seller = payable(msg.sender);
        _itemsSold.increment();

        _transfer(address(this), msg.sender, tokenId);
        approve(address(this), tokenId); //for future use so that contract is authorized to sell the nft

        payable(owner).transfer(listPrice);
        payable(seller).transfer(msg.value);
    }
}

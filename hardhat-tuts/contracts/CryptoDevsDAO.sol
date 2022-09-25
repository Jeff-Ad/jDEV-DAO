// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";


// Interface will be added here
//  Interface for the FakeNFTMarket 

interface IFakeNFTMarketplace{
    // returns the price of the an NFT from the FakeNFTMarketplace
    // returns the price in wei for an NFT
    function getPrice() external view returns (uint256);

// available() returns whether or not the given _tokenId has already been purchased
// Returns a boolean value - true if available, false if not 
    function available(uint256 _tokenId) external view returns (bool);
// purchase() purchases an NFT from the NFTMarket
    function purchase (uint256 _tokenId) external payable;
}
/*
Minimal interface for cryptodevsNft containing only two functions
that we are interested in 

*/

interface  ICryptoDevsNFT {
    // balanceOf returns the number of NFTs owned by the given address 
    // owner - address to fetch number of NFTs for 
    // returns - Returns the number of NFTs owned 
   function balanceOf(address owner) external view returns (uint256);

   // tokenOfOwnerByIndex returns a tokenID at a given index for owner 
   // Owner - address to fetch the NFT Tokens array to fetch 
   // index - index of NFT in ownes tokens array to fetch 
   // Returns the TokenID of the NFT 
function tokenOfOwnerByIndex(address owner , uint256 index) 
external 
view 
returns (uint256);
}



contract CryptoDevsDAO is Ownable {
// contract address code 
 /**
  * Now, since we will be calling functions on 
  * the FakeNFTMarketplace and CryptoDevsNFT contract, let's initialize variables for those contracts.
  */
 IFakeNFTMarketplace nftMarketplace;
 ICryptoDevsNFT cryptoDevsNFT;
 // Create a struct named Proposal containing all relevant information
struct Proposal {
 // nftTokenId - the tokenId of the NFT to purchase from FakeNFTMarketplace if the proposal passes 
uint256 nftTokenId;

// deadline - the UNIX timestamp unti which this proposal is active. Proposal can be executed after the deadline has been exceeded.
uint256 deadline;

// yayVotes - number of yay votes for this proposal
uint256 yayVotes;

//nayVotes - number of nay votes for this proposal
uint256 nayVotes;

// execute - whether or not this proposal has been executed yet. Cannot be executed before the deadline has been exceeded.
bool executed;

// Voters - a mapping of CryptoDevsNFT tokenIDs to booleans indicating whether that NFT has already been used to cast a vote or not 
 mapping(uint256 => bool) voters;

}
 // Create a mapping of ID to Proposal
 mapping(uint256 => Proposal) public proposals;
 // Number of proposals that have been created  
 uint256 public numProposals;


 /**
  * A Payable Constructor which initializes the contract 
  * instances for FakeNFTMarketplace and CryptoDevsNFT
  * The payable allows this constructor to accept an ETH deposit when it is being deployed 
  */
 constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
    nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
    cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
 }
 modifier nftHolderOnly(){
    require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
    _;
 }
/**
 *  createProposal allows a CryptoDevsNFT holder to create a new proposal in the DAO
 *  _nftTokenId - the tokenID of the NFT to be purchased from FakeNFTMaarketplace if this proposal passes 
 * Returns the proposal index for the newly created proposal
 */
 function createProposal(uint256 _nftTokenId)
 external 
 nftHolderOnly
 returns (uint256)
 {
    require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
    Proposal storage proposal = proposals[numProposals];
    proposal.nftTokenId = _nftTokenId;

    proposal.deadline = block.timestamp + 5 minutes;
    numProposals++;
    return numProposals - 1 ;
 }
// Create a modifier which only allows a function to be 
// called if the given proposal's deadline has not been exceeded yet

modifier activeProposalOnly(uint256 proposalIndex) {
    require(
        proposals[proposalIndex].deadline > block.timestamp,
        "DEADLINE_EXCEEDED"
    );
    _;
}

// Create an enum named Vote containing possible options for a vote 
enum Vote {
    YAY, 
    NAY
}
/**
 * The VoteonProposal function 
 */
// voteOnProposal allows a cryptoDevsNft Holder to cast their vote on an active proposal
// proposalIndex - the index of the proposal to vote on in the proposals array
// vote - the type of vote they want to cast 
function voteOnProposal(uint256 proposalIndex, Vote vote)
    external 
    nftHolderOnly
    activeProposalOnly(proposalIndex)
{
    Proposal storage proposal = proposals[proposalIndex];
    uint256 voterNFTBalanace = cryptoDevsNFT.balanceOf(msg.sender);
    uint256 numVotes = 0;
// calculate how many NFTs are owned by the voter 
// that haven't already been used for voting on this proposal
 for(uint256 i = 0; i < voterNFTBalanace; i++){
uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
if (proposal.voters[tokenId] == false){
    numVotes++;
    proposal.voters[tokenId] = true;
 }
}
require(numVotes > 0, "ALREADY_VOTED");
if(vote == Vote.YAY) {
    proposal.yayVotes += numVotes;
}else{
    proposal.nayVotes += numVotes;
}
}
modifier inactiveProposalOnly(uint256 proposalIndex){
    require(
        proposals[proposalIndex].deadline <= block.timestamp,
        "DEADLINE_NOT_EXCEEDED"
    );
    require(
    proposals[proposalIndex].executed == false, 
    "PROPOSAL_ALREADY_EXECUTED"
    );
    _;
}
// executeProposal allows any CryptoDevsNFT holder to execte a proposal after it's deadline has been exceeded 
// proposalIndex - the index of the proposal to execute in the proposals array
function executeProposal(uint256 proposalIndex)
    external 
    nftHolderOnly
    inactiveProposalOnly(proposalIndex)
    {
        Proposal storage proposal = proposals[proposalIndex];

//  * if the proposal has more YAY votes than NAY votes 
//  * purchase the NFT from the FakeNFTMarketplace 
 
if(proposal.yayVotes > proposal.nayVotes) {
    uint256 nftPrice = nftMarketplace.getPrice();
    require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
    nftMarketplace.purchase{value: nftPrice} (proposal.nftTokenId);
}

proposal.executed = true;
    }
    // withdrawEther allows the contract owner (deployer) to withdraw the ETH from the contract 
    function withdrawEther() external onlyOwner {
        payable (owner()).transfer(address(this).balance);
    }
    // allows for the contract to accept ETH deposits directly
    // from a wallet w/o calling a fxn
    receive() external payable {}
    
    fallback() external payable {}
}

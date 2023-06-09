// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* 
This is a rudementary prototype / proof of concept for a complex novel NFT based 
Liquid Democracy Governance structure for SCAOs - Smart Contract Assisted Organizations 
( see: https://www.klemen-cy.com/blockchain/scao for more information )

-------------
Introduction: 
-------------

In the following smart contract individual SCAO users are represented by ERC-721 NFTs which 
are utilized in governance.

SCAO users use their NFTs to gain access to voting on proposals according to 'Alternative Vote' 
(aka Instant Runoff) voting system rules (see: https://www.youtube.com/watch?v=3Y3jE3B8HsE).

In the future more voting systems will be implemented
(e.g.: Single Transferable Vote, or Mixed Member Proportional)



-----------------
The voting system
-----------------

The voting data is gathered and stored on - chain, but calculated off - chain by listening to 
events using web3.js or ethers.js (will be built later if more resources are available).


For a comprehensive explanation of the Governance idea & the voting systems see:

https://www.klemen-cy.com/blockchain/scao/governance    and
https://www.klemen-cy.com/blockchain/scao/governance/voting

Also see the explanation of the extra layer of decentralization available through Axelar:

https://www.klemen-cy.com/blockchain/sufficient-decentralization

THis smart contract was authored by Klemen Skornisek ^^,
*/

import 'NFT.sol';

contract TestNFTGovernance {

/*---------------------------------------------------------------------------------------
            State variables
---------------------------------------------------------------------------------------*/

address Owner; //Owner of this smart contract
address ERC721ContractAddress; //The Smart Contract of the NFTs used for voting

/*---------------------------------------------------------------------------------------
            State functions
---------------------------------------------------------------------------------------*/

function setOwner(address _newOwner) onlyOwner external {
        Owner = _newOwner;
    }

function setERC721ContractAddress (address _ERC721ContractAddress) onlyOwner external {
    ERC721ContractAddress = _ERC721ContractAddress;
}

/*---------------------------------------------------------------------------------------
            Modifiers
---------------------------------------------------------------------------------------*/

modifier onlyOwner(){
        require(msg.sender == Owner, "Only the contract owner can call this function");
        _;
    }

/*---------------------------------------------------------------------------------------
            Constructor
---------------------------------------------------------------------------------------*/

constructor() {
        Owner = msg.sender;
    }

/*---------------------------------------------------------------------------------------
            Events
---------------------------------------------------------------------------------------*/

//Emitted when a new voting proposal is proposed
event newProposalProposed(
        uint proposalId,
        string proposalName, 
        string option1,
        string option2,
        string option3,
        string option4);

/*Emitted when a voter votes - ethers.js or web3.js listens to these events and calculates 
election result off-chain*/
event voterVoted(
    uint NFTtokenId,//Token ID used to check if the address owns NFT and is able to vote
    uint votingProposalId,//proposal # (to be voted on)
    string Voteroption1, //Most favorite option
    string Voteroption2, //Next best choice
    string Voteroption3, //Third best choice
    string Voteroption4); //Least favorite choice


//Emitted when voting for a proposal has ended
event votingEnded(uint proposalId);

/*---------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------
            Voting

For the purposes of this hackathon, only Alternative Vote was attempted (since it's the simplest)

Future iterations of Governance smart contracts might split Alternative vote, 
Mixed Member Proportional or Single transferable Vote into seperate cotnracts, or keep
them in the same one ? Full optimizations are unknown at this time and require experimentation.

---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------------------
            Voting: Proposals

The following code enables multiple proposals to be voted on over time. 
Proposals are stored in an array, but may get further optimizations in future iterations.
---------------------------------------------------------------------------------------*/

    struct VotingProposals {
        string proposalName;
        string option1; //Note: options are various voting choices (e.g.: candidate, budget etc...)
        string option2;
        string option3;
        string option4;
    }

    VotingProposals[] public proposalList; //Storage of proposals

//Mapping that checks if proposal is open for voting ? proposalID => bool
    mapping(uint => bool) isVotingOpen; //checks if proposal can be voted on

//This function checks the latest proposal ID #
    function getNumberOfProposals() public view returns(uint) {
        return proposalList.length - 1; //Returns the proposal ID (starts with 0)
    }

//The following function creates a new proposal to be voted on (returns proposal ID #)
    function newProposal(
        string memory _proposalName, 
        string memory _option1,
        string memory _option2,
        string memory _option3,
        string memory _option4
         ) public onlyOwner returns(uint) {

        VotingProposals memory p;
        p.proposalName = _proposalName;
        p.option1 = _option1;
        p.option2 = _option2;
        p.option3 = _option3;
        p.option4 = _option4;

        proposalList.push(p);

        isVotingOpen[proposalList.length - 1] = true; //Ensures voters can vote on proposal
        
        //emit event for new proposals
        emit newProposalProposed(
            proposalList.length - 1,
            _proposalName, 
            _option1,
            _option2,
            _option3,
            _option4 );

        return proposalList.length - 1; //returns the proposal ID number (starts with 0)
    }
    
// The following function returns individual proposal # data (will be optimized in the future)
    function getProposalData(uint _proposalId) public view returns(
        string memory, 
        string memory, 
        string memory, 
        string memory, 
        string memory
        )
        
        {
        
        return(
            proposalList[_proposalId].proposalName, 
            proposalList[_proposalId].option1, 
            proposalList[_proposalId].option2,
            proposalList[_proposalId].option3, 
            proposalList[_proposalId].option4
            );
     }


/*---------------------------------------------------------------------------------------
            Voting on Proposals

In Alternative Vote (see: https://www.youtube.com/watch?v=3Y3jE3B8HsE) instead of choosing one 
candidate, voters rank their candidates from Most favorite to least favorite.

Note: strings are used for simplicity ... not very gas efficient... in the future if more
resources are available a real programer will utilize bytes or whatever is most efficient.

Note: further optimizations will be made in the future (for example: flexible number of options etc.)
---------------------------------------------------------------------------------------*/


//The following struct is the individual voters' preference list (individual voters' rankings)
    struct AlternativeVote {
        string option1; // favorite option
        string option2; // 2nd favorite
        string option3; // 3rd favorite
        string option4; // least favorite
}

/*The following mapping stores individual voters' votes 
(addresses that hold NFTs & their individual preference lists)
Mapping stores proposal ID => mapping( address => voting options preference list)*/
    mapping(uint => mapping(address => AlternativeVote)) public votingData;

//The following function allows voters to vote:
    function vote(
    uint _NFTtokenId,//NFT ID used to check if the voting address owns an NFT and can vote
    uint _votingProposalId,//proposal # that is voted on
    string memory _option1, //Most favorite option
    string memory _option2, //Next best choice
    string memory _option3, //Third best choice
    string memory _option4  //Least favorite choice
    ) public {
        
//Checks if voting address holds NFT  https://www.youtube.com/watch?v=YxU87o4U5iw&list=PLbbtODcOYIoE0D6fschNU4rqtGFRpk3ea&index=21
        
        //defining external contract
        ERC721 nfts = ERC721(ERC721ContractAddress); 
        
        //requires that voting address holds NFT
        require(
            nfts.ownerOf(_NFTtokenId) == msg.sender 
        );

        //requires that voting on the proposal is open
        require( isVotingOpen[_votingProposalId] == true, "voting on this proposal is closed");

        //Future optimization: Potentially Require that each NFT only votes once (depends on calculation)
        votingData[_votingProposalId][msg.sender].option1 = _option1;
        votingData[_votingProposalId][msg.sender].option2 = _option2;
        votingData[_votingProposalId][msg.sender].option3 = _option3;
        votingData[_votingProposalId][msg.sender].option4 = _option4;

        //Emit voter (NFT id #) voted (ranking of options) & then result is calculated off - chain 
        emit voterVoted(
            _NFTtokenId, 
            _votingProposalId, 
            _option1, 
            _option2, 
            _option3, 
            _option4);
    }

//The following function ends voting on the proposal
function endVote(uint _proposalId) public onlyOwner {
    
    isVotingOpen[_proposalId] = false;

    //voting of proposal ID # ended
    emit votingEnded(_proposalId);
}

}

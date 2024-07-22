# Introduce to DecentralElect

## Three Methods

DecentralElect provides three approaches for deploying voting systems on the blockchain: DecentralElect, NaiveElect, and PartitionDecentralElect. Corresponding smart contracts can be found in the contract files. You can use the provided test.ipynb to deploy and execute the voting systems.

* NaiveElect uses standard symmetric encryption and does not guarantee anonymity through linkable ring signatures.
* DecentralElect employs linkable ring signatures but does not utilize Partition ring signatures, which means its complexity grows polynomially with the number of participants.
* PartitionDecentralElect balances both anonymity and computational complexity, making it suitable for handling votes involving over a thousand participants.

## Four Tech
In this chapter, we delve into four critical technologies utilized in this voting system. First, we explore how ring signatures are employed to ensure voter anonymity. Next, we address the issue of double voting by the same individual using linkable ring signatures. To solve the problem of premature opening of votes, we implement the commit-reveal scheme. Finally, to balance the reduction of overall election costs and the protection of voter privacy, we adopt the partition ring method. This chapter provides a detailed explanation of these four key technologies.

### Ring Signature Scheme

Preserving the anonymity of voting presents a challenge when employing traditional digital signature techniques, as they risk divulging the signer's identity, thus compromising the integrity of the vote.
Enter ring signatures, a solution to this problem. The defining characteristic of ring signatures is their capacity to mask the identity of the signer within a group of other signers, forming a circular chain of signatures. Only individuals possessing at least one private key from within the ring can generate such a signature. Conversely, it should be challenging for an individual to generate a legitimate ring signature for any given message without possessing any of the private keys.

In the context of a ring signature, a group of entities is defined, each possessing their unique public/private key pairs denoted as $(pk_1, sk_1)$, $(pk_2, sk_2)$, $\ldots$, $(pk_n, sk_n)$. When an entity, say $i$, wishes to sign a message $m$, they employ their individual secret key ($sk_i$) alongside the public keys of the other members within the group $(m, sk_i, pk_1, \ldots, pk_n)$. This design enables the verification of the group's authenticity using the group's public key, while preventing the derivation of a valid signature without knowledge of the private keys within the group.

### Linkable Ring Signature

The anonymity provided by ring signatures opens the door to potential ㄉrepeated voting by the same individual, as their identity remains indistinguishable. Consequently, Joseph K. Liu et al. introduced the innovative concept of Linkable Ring Signatures \cite{liu2004linkable}. Incorporati a unique identifier  $y$ into the signature distnginguishes a specific signer, allowing different messages from that signer to be identified as originating from the same key. Additionally, employing hash functions ensures the complexity of establishing a link between the identifier and the key, thereby preserving anonymity.

### Commit-Reveal Scheme

Even with linkable ring signatures, voting systems still face a serious issue: "premature opening." Premature opening means the voting results are known early, which can discourage people from voting. In decentralized systems, there is no mechanism to prevent others in the community from peeking at the voting results during the voting phase. It is challenging to cryptographically separate the voting phase from the revealing phase decisively.

To address this, someone proposed the Commit-Reveal Scheme. The Commit-Reveal Scheme is a cryptographic protocol designed to enhance privacy and security in various blockchain applications by splitting the information disclosure process into two distinct phases: commit and reveal. In the commit phase, participants submit a hashed version of their information, effectively hiding the original data while proving its existence. Later, in the reveal phase, they disclose the original information, which the network verifies by comparing it to the initial hash. This two-step process ensures that sensitive data remains confidential during the commitment period and is only revealed at the appropriate time, fostering trust and transparency in activities such as voting, auctions, and sealed-bid contracts.

### Partition Ring

There remains one final issue with ring signatures that has not been previously discussed: the polynomial time complexity of the computational load.  As the number of participants in the ring signature increases, the ring size grows, leading to a larger overhead for each individual signature.

To address the issue of the ring size increasing with the number of voters, we partition the voters, distributing them into different clusters. Each voter then uses the public keys of other voters within their cluster to sign their ring signature.

However, it is evident that the anonymity of each voter, which was originally hidden among all voters, now becomes limited to their cluster. Consequently, if a cluster contains only two voters, it is easy for one voter to infer the candidate chosen by the other voter, thereby violating the principle of anonymous voting. Therefore, the size of the clusters must be appropriately determined.

## Five Phases

### Setup Phase

The initiator of the voting process first establishes a contract on Ethereum for voting purposes, specifying the voting topic, candidates, and detailing voting logistics, including dates and times for voting, verification, and result announcement. Additionally, a small amount of candidate information is provided to enable voters to ascertain the legitimacy of the election.

### Registration Phase

The primary objective of the Register phase within a voting system is to collect the public keys of eligible voters, ensuring their authentication and enabling their participation in the voting process securely. In a national election scenario, voter registration could be executed through the following:

(1) Registration Stations: Physical stations where citizens register using their digital identity cards. This method guarantees that only individuals possessing legitimate identity cards can enroll and engage in the voting process.

(2) Government-Facilitated Registration: If the initiator is a governmental body, citizens' public keys might already be in possession of the government. Consequently, the Registration phase could be conducted internally, utilizing the government's existing citizen database.

(3) Online Registration Portal: An online platform could be developed where citizens with digital identity cards upload their public keys securely using digital signatures. This approach ensures convenient registration while safeguarding the participation of only those with valid digital identities.

The Register phase acts as the linchpin connecting voters to their public keys, verifying identities, and maintaining voting process integrity. Tailored registration methods effectively authenticate voters, ensuring electoral legitimacy.

### Vote Phase

During the Vote Phase, voters wield the ability to remotely cast their votes worldwide via the internet. With their system-endorsed public and private key pair and their chosen candidate in hand, they initiate the ballot creation process. This involves merging their candidate's number with a random counterpart, then employing a specialized hashing algorithm for irreversible transformation. Following this, the vote's hash undergoes cryptographic signing using the private key and is jointly uploaded with the public key to the contract, thereby concluding the voting sequence. Leveraging a predefined function, voters can ascertain the success of their vote by verifying existing records tied to their public key. By meeting the requisite gas fees for miners' computational efforts, they seamlessly integrate their voting outcomes into the blockchain.

### Reveal Phase

In the Reveal phase, voters demonstrate the relationship between their cast ballot and its corresponding hash value, thereby indirectly confirming the existence of a vote for a particular candidate during the vote phase. It is foreseeable that indiscernible candidate numbers may also be included in the pool of hashed ballots. Hence, caution is warranted during the vote phase in selecting and securely storing the ballot to ensure its successful disclosure during the reveal phase for the vote to be counted accurately. The significance of the reveal phase lies in its preventive measure against premature disclosure of voting outcomes, detailed reasons for which will be discussed in the methodology section of the subsequent chapter.

### Declare Phase

In the Declaration Phase, in addition to revealing the actual voting results, metrics such as the vote rate and reveal rate are also disclosed to assess whether the voting outcomes adequately represent the entire community's opinions, detect any discrepancies, and determine if a revote is necessary.
In our hypothetical scenario of citizen voting in K-country, we introduce a policy of providing subsidies based on ballot receipts to encourage public participation and increase voter turnout. With smart contracts recording all state transitions, obtaining records of public-private key pairs of voters who have successfully cast and revealed their votes is straightforward. Leveraging this record, the government can provide ETH subsidies to participating voters' accounts, thereby reallocating funds from traditional voting procedures to decentralized miners.

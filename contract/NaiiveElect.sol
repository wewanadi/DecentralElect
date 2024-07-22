// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib/altbn128.sol";

contract DecentralElect {
    
    using Curve for Curve.G1Point;
    
    enum Status { Unopened, Registration, Vote, Verification, Declaration}

    struct Voter {
        uint256 chiaveX;
        uint256 chiaveY;
    }

    struct Candidate {
        uint256 id;
        string name;
        string description;
        uint vote;
    }

    struct Election {
        Status status;
        string subject;
        Candidate[] candidates;
        uint256[] voters_x;
        Voter[] voters;

        bytes32 pkHashAccumulator;
        mapping(uint256 => bool) registration_record;
        mapping(uint256 => bool) vote_record;
        mapping(uint256 => bool) ballot_hash_pool;
        mapping(uint256 => bool) verification_record;
    }
    
    mapping(uint256 => Election) public elections;
    
    address public manager;
    address public registerManager;
    
    modifier onlyManager {
        require(msg.sender == manager);
        _;
    }
    
    modifier onlyRegisterManager {
        require(msg.sender == registerManager);
        _;
    }

    constructor(address _registerManager) {
        manager = msg.sender;
        registerManager = _registerManager;
    }
    
    // Manager functions 
    function create_election(uint256 identifier, string calldata subject) external onlyManager {
        Election storage election = elections[identifier];
        require(election.status == Status.Unopened, "An error occurred: CreateError: election already exists");
        election.status = Status.Registration;
        election.subject = subject;
    }

    function set_candidate(uint256 identifier, string calldata name, string calldata description) external onlyManager {
        Election storage election = elections[identifier];
        require(election.status == Status.Registration, "An error occurred: StatusError: not registration status");

        Candidate memory candidate = Candidate(election.candidates.length, name, description, 0);

        election.candidates.push(candidate);
    }

    function register_voter(uint256 identifier, uint256 _chiave_x, uint256 _chiave_y) external onlyRegisterManager {
        Election storage election = elections[identifier];
        
        require(election.status == Status.Registration, "An error occurred: StatusError: not registration status");
        require(!election.registration_record[_chiave_x], "An error occurred: RegistrationError: Duplicate registration");

        if (election.voters_x.length == 0) {
            election.pkHashAccumulator = keccak256(abi.encodePacked(_chiave_x));
        } else {
            election.pkHashAccumulator = keccak256(abi.encodePacked(election.pkHashAccumulator, _chiave_x));
        }

        election.voters_x.push(_chiave_x);
        election.voters.push(Voter(_chiave_x, _chiave_y));
        election.registration_record[_chiave_x] = true;
    }

    // Status control
    function start_vote(uint256 identifier) external onlyManager {
        Election storage election = elections[identifier];
        require(election.status == Status.Registration, "An error occurred: StatusError: not registration status");
        require(election.candidates.length > 0, "An error occurred: VotersError: no candidate in candidates set");
        require(election.voters_x.length > 0, "An error occurred: VotersError: no votres in voters set");
        election.status = Status.Vote;
    }

    function stop_vote(uint256 identifier) external onlyManager {
        Election storage election = elections[identifier];
        require(election.status == Status.Vote, "An error occurred: StatusError: not vote status");
        election.status = Status.Verification;
    }

    function stop_verification(uint256 identifier) external onlyManager {
        Election storage election = elections[identifier];
        require(election.status == Status.Verification, "An error occurred: StatusError: not verification status");
        election.status = Status.Declaration;
    }


    // Voter function
    function vote(uint256 identifier, uint256[2] calldata tag, uint256[] calldata tees, uint256 seed, uint256 ballot_hash) external {
        Election storage election = elections[identifier];
        require(election.status == Status.Vote, "An error occurred: StatusError: not vote status");
        require(tees.length == election.voters_x.length, "An error occurred: RingSignatureError: The ring signature, to be valid, must be as long as the number of voters.");
        require(!election.vote_record[tag[0]], "An error occurred: VoteError: duplicate voting");
        require(!election.ballot_hash_pool[ballot_hash], "An error occurred: VoteError: This ballot_hash has been chosen");
        require(verifyRingSignature(ballot_hash, tag, tees, seed, identifier), "An error occurred: VoteError: invalid ring signature");

        election.vote_record[tag[0]] = true;
        election.ballot_hash_pool[ballot_hash] = true;
    }

    function verify_ballot(uint256 identifier, string memory ballot, uint256 ballot_hash) external {
        Election storage election = elections[identifier];
        require(election.status == Status.Verification, "An error occurred: StatusError: not verification status");
        require(election.ballot_hash_pool[ballot_hash], "An error occurred: VoteError: not find the bollat hast in the pool");
        require(!election.verification_record[ballot_hash], "An error occurred: VerificationError: this ballot has been verified");

        uint256 _ballot_hash = bytesToBigNumber(keccak256(abi.encode(ballot)));
        require(ballot_hash == _ballot_hash, "An error occurred: HashError: result of the hash not match");

        uint256 vote_to = extractFirstNumber(ballot);
        require(vote_to >= 0 && vote_to < election.candidates.length, "An error occurred: VoteError: the candidate number does not exist.");
        election.candidates[vote_to].vote += 1;

        election.verification_record[ballot_hash] = true;
    }

    function get_status(uint256 identifier) external view returns (Status) {
        return elections[identifier].status;
    }

    function get_candidates(uint256 identifier) external view returns (Candidate[] memory) {
        Election storage election = elections[identifier];
        return election.candidates;
    }
    
    function check_if_registered(uint256 identifier, uint256 _chiave_x) external view returns (bool) {
        return elections[identifier].registration_record[_chiave_x];
    }

    function get_registered_pkeys(uint256 identifier) external view returns (Voter[] memory) {
        return elections[identifier].voters;
    }

    function check_if_voted(uint256 identifier, uint256 tag_x) external view returns (bool) {
        return elections[identifier].vote_record[tag_x];
    }

    // internal function
    function bytesToBigNumber(bytes32 hash) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < 32; i++) {
            result = result + uint256(uint8(hash[i])) * (2**(8 * (31 - i)));
        }
        return result;
    }

    function extractFirstNumber(string memory input) internal pure returns (uint256) {
        uint256 result = 0;
        bool foundDigit = false;

        for (uint256 i = 0; i < bytes(input).length; i++) {
            bytes1 char = bytes(input)[i];

            if (char >= '0' && char <= '9') {
                result = result * 10 + uint8(char) - uint8(bytes1('0'));
                foundDigit = true;
            } else if (foundDigit) {
                break;
            }
        }

        require(foundDigit, "An error occurred: VoteError: no leading number in the vote");

        return result;
    }

    function verifyRingSignature(uint256 voteData, uint256[2] memory tag, uint256[] memory tees, uint256 seed, uint256 identifier) public view returns (bool) {
        Election storage election = elections[identifier];
        Curve.G1Point memory L = Curve.HashToPoint(uint256(election.pkHashAccumulator));
        Curve.G1Point memory M = Curve.HashToPoint(voteData);
        Curve.G1Point memory T = Curve.G1Point(tag[0], tag[1]);
        uint256 h = uint256(keccak256(abi.encodePacked(M.X, M.Y, T.X, T.Y)));

        uint256 c = seed;
        for(uint256 i = 0; i < election.voters_x.length; i++) {
            c = uint256(keccak256(abi.encodePacked(
                    h,
                    RingLink(
                        Curve.G1Point(election.voters[i].chiaveX, election.voters[i].chiaveY),
                        // Curve.G1Point(election.voters_x[i], voters[election.voters_x[i]].chiaveY),
                        L,
                        T,
                        tees[i],
                        c
                    ))));
        }
        return c == seed;
    }
    
    function RingLink(Curve.G1Point memory Y, Curve.G1Point memory M, Curve.G1Point memory tagpoint, uint256 s, uint256 c) internal view returns (uint256) {
        Curve.G1Point memory a = Curve.g1add(Curve.g1mul(Curve.P1(), s), Curve.g1mul(Y, c));
        Curve.G1Point memory b = Curve.g1add(Curve.g1mul(M, s), Curve.g1mul(tagpoint, c));

        return uint256(keccak256(abi.encodePacked(
            tagpoint.X, tagpoint.Y,
            a.X, a.Y,
            b.X, b.Y
        )));
    }
}

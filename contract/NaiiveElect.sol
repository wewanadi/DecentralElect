// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib/altbn128.sol";

contract NaiiveElect {
    
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

    constructor() {
        manager = msg.sender;
        registerManager = msg.sender;
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
    function vote(uint256 identifier, uint256[2] calldata public_keys, uint256 ballot_hash, uint256[2] calldata signature) external {
        Election storage election = elections[identifier];
        require(election.status == Status.Vote, "An error occurred: StatusError: not vote status");
        require(!election.vote_record[public_keys[0]], "An error occurred: VoteError: duplicate voting");
        require(!election.ballot_hash_pool[ballot_hash], "An error occurred: VoteError: This ballot_hash has been chosen");
        require(verifySignature(public_keys, ballot_hash, signature), "An error occurred: VoteError: invalid ring signature");

        election.vote_record[public_keys[0]] = true;
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

    function check_if_verified(uint256 identifier, uint256 ballot_hash) external view returns (bool) {
        return elections[identifier].verification_record[ballot_hash];
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

    // Computes the modular inverse of a number
    // @param a: The number to compute the inverse of
    // @param n: The modulus
    // @return: The modular inverse of a mod n
    function modInverse(uint256 a, uint256 n) internal pure returns (uint256) {
        (uint256 t, uint256 newT, uint256 r, uint256 newR) = (0, 1, n, a);
        while (newR != 0) {
            uint256 quotient = r / newR;
            (t, newT) = (newT, addmod(t, n - mulmod(quotient, newT, n), n));
            (r, newR) = (newR, r - quotient * newR);
        }
        require(r <= 1, "Inverse does not exist");
        return t;
    }

    // Verifies an ECC signature
    // @param publicKeyX: The X coordinate of the public key as uint256
    // @param publicKeyY: The Y coordinate of the public key as uint256
    // @param message: The message being signed (as bytes32)
    // @param r: The r value of the signature
    // @param s: The s value of the signature
    // @return: True if the signature is valid, otherwise false
    function verifySignature(
        uint256[2] calldata public_keys,
        uint256 message,
        uint256[2] calldata signature
    ) internal view returns (bool) {
        // Construct the public key point
        Curve.G1Point memory publicKey = Curve.G1Point(public_keys[0], public_keys[1]);

        uint256 r = signature[0];
        uint256 s = signature[1];

        // Hash the message to get the message digest
        uint256 z = uint256(message);

        // Calculate w = s^(-1) mod N
        uint256 w = modInverse(s, Curve.N());

        // Calculate u1 = z * w mod N
        uint256 u1 = mulmod(z, w, Curve.N());

        // Calculate u2 = r * w mod N
        uint256 u2 = mulmod(r, w, Curve.N());

        // Calculate the curve points
        Curve.G1Point memory G = Curve.P1();
        Curve.G1Point memory point1 = G.g1mul(u1);
        Curve.G1Point memory point2 = publicKey.g1mul(u2);

        // Add the points
        Curve.G1Point memory R = point1.g1add(point2);

        // Verify if R.x == r
        return R.X == r;
    }
}

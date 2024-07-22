// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib/altbn128.sol";

contract ParitionDecentralElect {
    
    using Curve for Curve.G1Point;
    
    enum Status { Unopened, Registration, Cluster, Vote, Verification, Declaration}

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
        mapping (uint256 => Voter) voters;
        uint256 voter_length;
        uint256 cluster_progress;

        mapping (uint256 => Voter[10]) constituencys;
        mapping (uint256 => bytes32) pkHashAccumulators;
        mapping(uint256 => bool) registration_record;
        mapping(uint256 => bool) vote_record;
        mapping(uint256 => bool) ballot_hash_pool;
        mapping (uint256 => uint256) constituency_record;
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
        election.voter_length = 0;
        election.cluster_progress = 0;
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

        election.voters[election.voter_length]= Voter(_chiave_x, _chiave_y);
        election.voter_length += 1;
        election.registration_record[_chiave_x] = true;
    }

    // Status control
    function cluser_voters(uint256 identifier) external onlyManager {
        Election storage election = elections[identifier];

        Status status = election.status;
        uint candidates_length = election.candidates.length;
        uint voter_length = election.voter_length;
        uint cluster_progress = election.cluster_progress;

        require(status == Status.Registration || status == Status.Cluster , "An error occurred: StatusError: not registration status or cluster status");
        require(candidates_length > 0, "An error occurred: VotersError: no candidate in candidates set");
        require(voter_length > 0, "An error occurred: VotersError: no voters in voters set");
        require(cluster_progress < voter_length, "An error occurred: VlusterError: cluster status has finished");

        uint idx;
        uint cid;
        for(idx = cluster_progress;idx < voter_length; idx++) {
            if (cluster_progress + 50 == idx) {
                election.cluster_progress += 50;
                election.status = Status.Cluster;
                return;
            }
            cid = idx/10;
            uint vid = idx%10;

            election.constituencys[cid][vid] = election.voters[idx];
            election.constituency_record[election.voters[idx].chiaveX] = cid;

            if (vid == 0) {
                election.pkHashAccumulators[cid] = keccak256(abi.encodePacked(election.voters[idx].chiaveX));
            } else {
                election.pkHashAccumulators[cid] = 
                keccak256(abi.encodePacked(election.pkHashAccumulators[cid], election.voters[idx].chiaveX));
            }
        }
        cluster_progress += idx - cluster_progress;

        if (voter_length %10 != 0) {
            Voter[10] memory fake = [
                Voter(11106386159621965730627392074028092959287082734140641673780701127763299291135, 11668878437222138835744390893078222545652809807209121283913888025057583291055),
                Voter(14935920911450443253190751991713696716472160410277440100887004524814126866352, 19188781568263839841111125691284205087568458885970060115097776893487200384427),
                Voter(15794516413134049960747293200112643748973602648199884363205427602088672394206, 21566094810561167949929854665954880579248448424338570701673264052699481608637),
                Voter(17063201443043592843866506260764595297652040824205069142511292417841840448500, 1045651780764082507301048817206430577053372547047421258185268140979748019059),
                Voter(5790603386617154948865113745917299960221421655281227473199353643979683242549, 21374391475914204575608507447546181244435591915349530650609156889039282622734),
                Voter(14239152657442769196265447620709668598885263373473428125712951750970512641298, 303270522611625687804895260143617977134590734446502097709891782917350428952),
                Voter(11016539687303131520138493175747995132028899639960208605805391888153490137532, 9473746011451812587780470204280605770789843874116310336327589707868130843564),
                Voter(3063722494684578731141693189411129424599720020868849454722622680068918250466, 5971790380599113595655330690029634675352281636380063631204680441546579956251),
                Voter(7562739262581254246071299113576939828129884468933345909803956057448060850048, 13524807336004286534723880489346117483047367340499249728700474373988784542919),
                Voter(5930690715916264697986828679914322130778782535742892200599031215752799557136, 3826930963016379567274066343192749472821607975117316986996003907326716884508)
                ];

            cid = idx/10;
            for(uint i = idx%10; i<10; i++) {
                election.pkHashAccumulators[cid] = keccak256(abi.encodePacked(election.pkHashAccumulators[cid], fake[i-1].chiaveX));
                election.constituencys[cid][i] = fake[i-1];
                election.constituency_record[fake[i-1].chiaveX] = cid;
                cluster_progress ++;
            }
        }
        election.cluster_progress = cluster_progress;
        election.status = Status.Cluster;
    }

    function start_vote(uint256 identifier) external onlyManager {
        Election storage election = elections[identifier];
        require(election.status == Status.Cluster, "An error occurred: StatusError: not cluster status");
        election.status = Status.Vote;
    }

    function get_cluster_progress(uint256 identifier) external onlyManager view returns (uint256, uint256) {
        return (elections[identifier].cluster_progress, elections[identifier].voter_length);
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

    function vote(uint256 identifier, uint256 constituency_idx, uint256[2] calldata tag, uint256[] calldata tees, uint256 seed, uint256 ballot_hash) external {
        Election storage election = elections[identifier];
        require(election.status == Status.Vote, "An error occurred: StatusError: not vote status");
        require(tees.length == 10, "An error occurred: RingSignatureError: The ring signature, to be valid, must be as long as the number of voters.");
        require(!election.vote_record[tag[0]], "An error occurred: VoteError: duplicate voting");
        require(!election.ballot_hash_pool[ballot_hash], "An error occurred: VoteError: This ballot_hash has been chosen");
        require(verifyRingSignature(ballot_hash, tag, tees, seed, identifier, constituency_idx), "An error occurred: VoteError: invalid ring signature");

        election.vote_record[tag[0]] = true;
        election.ballot_hash_pool[ballot_hash] = true;
    }

    function verify_ballot(uint256 identifier, string memory ballot, uint256 ballot_hash) external {
        Election storage election = elections[identifier];
        require(election.status == Status.Verification, "An error occurred: StatusError: not verification status");
        require(election.ballot_hash_pool[ballot_hash], "An error occurred: VoteError: not find the bollat hash in the pool");
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

    function get_constituency(uint256 identifier, uint256 _chiave_x) external view returns (uint256) {
        require(elections[identifier].status == Status.Vote, "An error occurred: StatusError: not vote status");
        return elections[identifier].constituency_record[_chiave_x];
    }

    function get_registered_pkeys(uint256 identifier, uint256 constituency) external view returns (Voter[10] memory) {
        return elections[identifier].constituencys[constituency];
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

    function verifyRingSignature(
        uint256 voteData,
        uint256[2] memory tag,
        uint256[] memory tees,
        uint256 seed,
        uint256 identifier,
        uint256 constituency_idx
    ) public view returns (bool) {
        Election storage election = elections[identifier];
        Curve.G1Point memory L = Curve.HashToPoint(uint256(election.pkHashAccumulators[constituency_idx]));
        Curve.G1Point memory M = Curve.HashToPoint(voteData);
        Curve.G1Point memory T = Curve.G1Point(tag[0], tag[1]);
        uint256 h = uint256(keccak256(abi.encodePacked(M.X, M.Y, T.X, T.Y)));

        return checkRingSignature(identifier, L, T, tees, seed, h, constituency_idx);
    }

    function checkRingSignature(
        uint256 identifier,
        Curve.G1Point memory L,
        Curve.G1Point memory T,
        uint256[] memory tees,
        uint256 seed,
        uint256 h,
        uint256 constituency_idx
    ) internal view returns (bool) {
        Election storage election = elections[identifier];
        uint256 c = seed;
        for (uint256 i = 0; i < 10; i++) {
            uint256 r = RingLink(Curve.G1Point(election.constituencys[constituency_idx][i].chiaveX, election.constituencys[constituency_idx][i].chiaveY), L, T, tees[i], c);
            c = uint256(keccak256(abi.encodePacked(h, r)));
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

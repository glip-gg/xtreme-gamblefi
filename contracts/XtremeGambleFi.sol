pragma solidity ^0.8.4;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract XtremeGambleFi is AccessControl {
 
    using ECDSA for bytes32;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    mapping(address => uint) public balances;

    struct XtremeMatch {
        uint matchId;
        uint initialMultiplier;
        uint winningPlayerId;
        uint status; // 1: started, 2: ended, 3: refunded, 4: challenged
        bytes32 logHash;
    }

    struct MatchPayout {
        uint matchId;
        uint payout;
        address winner;
    }

    struct MatchBet {
        address better;
        uint playerId;
        uint multiplier; // 1.5x, 12x etc, value will be saved as 150, 1200
        uint amount;
        uint outcome; // 1: win, 2: lose, 3: refund
    }

    mapping(uint => XtremeMatch) public matches;
    mapping(uint => MatchPayout[]) public matchPayouts;
    mapping(uint => MatchBet[]) public matchBets;

    error InvalidProof();
    error MatchChallenged();

    event MatchStarted(uint matchId, uint initialMultiplier);
    event MatchEnded(uint matchId, uint winner, bytes32 logHash);
    event BetPlaced(uint matchId, address better, uint playerId, uint multiplier, uint amount);
    event MatchRefunded(uint matchId);
    event MatchChallenged(uint matchId);
    event BetRefunded(uint matchId, address better);
    event BetPayout(uint matchId, uint payout, address winner);
    event BetLost(uint matchId, uint amount, address better);
    event UserDeposit(address user, uint amount);
    event UserWithdraw(address user, uint amount);
    event FeesWithdraw(uint amount);

    constructor() {
        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    function depositAndBet(
                uint amount,
                uint matchId, 
                uint playerId,
                uint multiplier,
                bytes multiplierSig) public payable {

        if (msg.value > 0) {
            balances[msg.sender] += msg.value;
            emit UserDeposit(msg.sender, msg.value);
        }
       
        // verify multiplier signature
        address signer = keccack256(abi.encode(matchId, playerId, multiplier)).recover(multiplierSig);
        if (!hasRole(MANAGER_ROLE, signer)) {
            revert InvalidProof();
        }

        _placeBet(msg.sender, amount, matchId);

        MatchBet memory newBet = MatchBet(msg.sender, playerId, multiplier, amount, 0);
        matchBets[matchId].push(newBet);

        emit BetPlaced(matchId, msg.sender, playerId, multiplier, amount);
    }
    
    function _placeBet(address better, uint amount, uint matchId) internal {
        require(balances[better] >= amount, "Insufficient balance");
        balances[better] -= amount;
    }

    function withdraw() public {
        uint amount = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit UserWithdraw(msg.sender, amount);
    }

    function withdrawFees() public onlyRole(OWNER_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
        emit FeesWithdraw(address(this).balance);
    }

    function startGame(uint matchId, uint initialMultiplier) public onlyRole(MANAGER_ROLE) {
        require(matches[matchId].matchId == 0, "Match already exists");
        XtremeMatch memory newMatch = XtremeMatch(matchId, initialMultiplier, -1, bytes(0));
        matches[matchId] = newMatch;
        emit MatchStarted(matchId, initialMultiplier);
    }

    function endAndSettleGame(uint matchId, uint winner, bytes32 logHash) public onlyRole(MANAGER_ROLE) {
        require(matches[matchId].matchId != 0, "Match does not exist");

        if (matches[matchId].status == 4) {
            revert MatchChallenged();
        }

        require(matches[matchId].logHash != bytes(0), "Match already ended");
        require(matches[matchId].status == 1, "Invalid match status");

        matches[matchId].winningPlayerId = winner;
        matches[matchId].logHash = logHash;

        MatchPayout[] memory matchPayouts = matchPayouts[matchId];
        require(matchPayouts.length == 0, "Match already paid out");

        MatchBet[] memory bets = matchBets[matchId];
        for (uint i = 0; i < bets.length; i++) {
            MatchBet storage bet = bets[i];
            if (bet.playerId == winner) {
                uint payout = (bet.amount * bet.multiplier) / 100;
                balances[bet.better] += payout;
                matchPayouts.push(MatchPayout(matchId, payout, bet.better));
                bet.outcome = 1;
                emit BetPayout(matchId, payout, bet.better);
            } else {
                bet.outcome = 2;
                emit BetLost(matchId, bet.amount, bet.better);
            }
        }
        emit MatchEnded(matchId, winner, logHash);
    }

    function refundMatchBets(uint matchId, bytes32 logHash) public onlyRole(MANAGER_ROLE) {
        require(matches[matchId].matchId != 0, "Match does not exist");
        require(matches[matchId].logHash != bytes(0), "Match already ended");
        require(matches[matchId].status == 1 || matches[matchId].status == 4, "Invalid match status");

        MatchBet[] memory bets = matchBets[matchId];
        for (uint i = 0; i < bets.length; i++) {
            MatchBet storage bet = bets[i];
            if (bet.outcome == 3) continue;
            balances[bet.better] += bet.amount;
            bet.outcome = 3;
            emit BetRefunded(matchId, bet.better);
        }

        matches[matchId].status = 3;
        emit MatchRefunded(matchId);
    }

    function refundBetManual(uint matchId, address better) public onlyRole(OWNER_ROLE) {
        require(matches[matchId].matchId != 0, "Match does not exist");

        MatchBet[] memory bets = matchBets[matchId];
        for (uint i = 0; i < bets.length; i++) {
            MatchBet storage bet = bets[i];
            if (bet.better == better) {
                if (bet.outcome == 3) break;
                balances[better] += bet.amount;
                bet.outcome = 3;
                emit BetRefunded(matchId, better);
            }
        }
    }

    function getLogHash(uint matchId) public view returns (bytes32) {
        return matches[matchId].logHash;
    }

    function challengeMatch(uint matchId) public onlyRole(VALIDATOR_ROLE) {
        require(matches[matchId].matchId != 0, "Match does not exist");
        require(matches[matchId].logHash != bytes(0), "Match already ended");
        require(matches[matchId].status == 1, "Invalid match status");

        matches[matchId].status = 4;
        
        emit MatchChallenged(matchId);
    }
}
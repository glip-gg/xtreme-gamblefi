pragma solidity ^0.8.4;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

interface IBlastPoints {
  function configurePointsOperator(address operator) external;
  function configurePointsOperatorOnBehalf(address contractAddress, address operator) external;
}

interface IBlast {
    function configureAutomaticYield() external;
    function configureClaimableGas() external;
    function claimAllGas(address contractAddress, address recipient) external returns (uint256);
}

contract XtremeGambleFi is AccessControl {
 
    using ECDSA for bytes32;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    mapping(address => uint) public balances;

    struct XtremeMatch {
        uint256 matchId;
        bytes32 logHash;
        uint16 initialMultiplier;
        uint8 winningPlayerId; // 0 - no winner yet
        uint8 status; // 1: started, 2: ended, 3: refunded, 4: challenged
    }

    struct MatchPayout {
        uint256 matchId;
        uint256 payout;
        address winner;
    }

    struct MatchBet {
        address better;
        uint256 amount;
        uint16 multiplier; // 1.5x, 12x etc, value will be saved as 150, 1200
        uint8 playerId;
        uint8 outcome; // 0: not processed, 1: win, 2: lose, 3: refund
    }

    mapping(uint => XtremeMatch) public matches;
    mapping(uint => MatchPayout[]) public matchPayouts;
    mapping(uint => MatchBet[]) public matchBets;

    error InvalidProof();
    error MatchChallengedError();

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
    event LogHashUpdated(uint matchId, bytes32 logHash);

    constructor(address blastPointsAddress) {
        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
        IBlastPoints(blastPointsAddress).configurePointsOperator(msg.sender);
        IBlast(0x4300000000000000000000000000000000000002).configureClaimableGas();
    }

    function depositAndBet(
                uint amount,
                uint matchId, 
                uint8 playerId,
                uint16 multiplier,
                bytes calldata multiplierSig) public payable {

        if (msg.value > 0) {
            balances[msg.sender] += msg.value;
            emit UserDeposit(msg.sender, msg.value);
        }
       
        require(matches[matchId].matchId != 0, "Match does not exist");
        require(matches[matchId].status == 1, "Invalid match state");

        // verify multiplier signature
        bytes32 multiplierHash = MessageHashUtils.toEthSignedMessageHash(keccak256(abi.encode(matchId, playerId, multiplier)));
        address signer = multiplierHash.recover(multiplierSig);
        if (!hasRole(MANAGER_ROLE, signer)) {
            revert InvalidProof();
        }

        _placeBet(msg.sender, amount, matchId);

        MatchBet memory newBet = MatchBet(msg.sender, amount, multiplier, playerId, 0);
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

    function startGame(uint matchId, uint16 initialMultiplier) public onlyRole(MANAGER_ROLE) {
        require(matches[matchId].matchId == 0, "Match already exists");
        XtremeMatch memory newMatch = XtremeMatch(matchId, bytes32(0), initialMultiplier, 0, 1);
        matches[matchId] = newMatch;
        emit MatchStarted(matchId, initialMultiplier);
    }

    function endAndSettleGame(uint matchId, uint8 winner, bytes32 logHash) public onlyRole(MANAGER_ROLE) {
        require(matches[matchId].matchId != 0, "Match does not exist");

        if (matches[matchId].status == 4) {
            revert MatchChallengedError();
        }

        require(matches[matchId].logHash == bytes32(0), "Match already ended");
        require(matches[matchId].status == 1, "Invalid match status");

        matches[matchId].winningPlayerId = winner;
        matches[matchId].logHash = logHash;
        matches[matchId].status = 2;

        emit LogHashUpdated(matchId, logHash);

        MatchPayout[] storage matchPayouts = matchPayouts[matchId];
        require(matchPayouts.length == 0, "Match already paid out");

        MatchBet[] memory bets = matchBets[matchId];
        for (uint i = 0; i < bets.length; i++) {
            MatchBet memory bet = bets[i];
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

    function setLogHash(uint matchId, bytes32 logHash) public onlyRole(VALIDATOR_ROLE) {
        require(matches[matchId].matchId != 0, "Match does not exist");
        matches[matchId].logHash = logHash;
        emit LogHashUpdated(matchId, logHash);
    }

    function refundMatchBets(uint matchId, bytes32 logHash) public onlyRole(MANAGER_ROLE) {
        require(matches[matchId].matchId != 0, "Match does not exist");
        require(matches[matchId].logHash != bytes32(0), "Match already ended");
        require(matches[matchId].status == 1 || matches[matchId].status == 4, "Invalid match status");

        matches[matchId].status = 3;

        MatchBet[] storage bets = matchBets[matchId];
        for (uint i = 0; i < bets.length; i++) {
            MatchBet storage bet = bets[i];
            if (bet.outcome == 3) continue;
            balances[bet.better] += bet.amount;
            bet.outcome = 3;
            emit BetRefunded(matchId, bet.better);
        }

        emit MatchRefunded(matchId);
    }

    function refundBetManual(uint matchId, address better) public onlyRole(OWNER_ROLE) {
        require(matches[matchId].matchId != 0, "Match does not exist");

        MatchBet[] storage bets = matchBets[matchId];
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
        require(matches[matchId].logHash != bytes32(0), "Match already ended");
        require(matches[matchId].status == 1, "Invalid match status");

        matches[matchId].status = 4;
        
        emit MatchChallenged(matchId);
    }

    function claimGasFees() public onlyRole(OWNER_ROLE) {
        IBlast(0x4300000000000000000000000000000000000002).claimAllGas(address(this), msg.sender);
    }
}
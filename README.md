## Xtreme GambleFi Protocol

Xtreme GambleFi is a trustless protocol and platform designed to provide an onchain betting experience around live games and esports.


Real time data from supported games (or any other source) is processed through the platform to provide end users a fully interactive onchain betting experience.

Currently, BTX (mobile shooter game) is live on the platform.

<img src="https://raw.githubusercontent.com/glip-gg/xtreme-gamblefi/main/assets/screenshot1.png">

<img src="https://raw.githubusercontent.com/glip-gg/xtreme-gamblefi/main/assets/screenshot2.png">


Xtreme GamebleFi contract is deployed on Blast at following address -
`0xe450fd1d63218a60a924a7ad94ab635f1d5483e0`

Points operator address - 
`0xeE8A0a905eB021761f0160bCc528C0aDEDC666E1`


## Game Manager

Game managers are entities controlling the games and their outcomes in a trustless way. When a game ends, a `logHash` is required to be submitted to process payouts from the contract. `logHash` is critical to maintain and verify the integrity of the data on which outcomes of bets were decided.

`function endAndSettleGame(uint matchId, uint winner, bytes32 logHash)`

Any user will be able to get the `logHash` and `matchId` of a match and use that to access raw logs of the match, and can verify that raw logs themselves match the provided `logHash`.

Since raw logs data are available publicly, anyone can also verify that the sequence of logs results in a particular outcome. 
We are also building a tool to view and analyse raw logs and their integrity.

## Deposit & Odds

Game Managers can have live odds in their games. E.g at start of game, when there are 12 initial players, odds of Player 1 winning is X1, but after couple of mins, only 8 players remain in game, then odds should change to X2.

Game managers are responsible for providing a `multiplier signature` to the users when users place a bet. Multiplier signature, is used to verify that the provided multiplier for a particular ingame user is valid.

`
depositAndBet(uint amount,
            uint matchId, 
            uint playerId,
            uint multiplier,
            bytes multiplierSig)
`
```solidity
address signer = keccack256(abi.encode(matchId, playerId, multiplier)).recover(multiplierSig);
if (!hasRole(MANAGER_ROLE, signer)) {
    revert InvalidProof();
}
```
## Game Validator

To make sure game data is not being tampered before logHash and eventual winner is decided (either from the game server itself or somewhere in between), validators are registered to the protocol which constantly monitor the real time data to find any anomalies in the data.

For example,
Bet was placed on Player 10 getting atleast 1 kill in the game, and a log is emitted that player 10 killed Player 2, however when analysing real time data, Validator notices that Player 10's 3d rotation values were not facing any player when kill was registered, or there was no bullet fired when the kill was registered. 

Game Validator's responsibilty is to identify such data anomalies in realtime and submit a challenge for that match.

`
function challengeMatch(uint matchId) public onlyRole(VALIDATOR_ROLE)
`

When a match is challenged, payouts at the end of game are paused automatically and bets are refunded.

We have designed an initial BTX Game Validator according to our set of rules and data points which we will be checking realtime. Other developers are also invited to build their own validators to process this real time data and to raise match challenges. Validators are also rewarded for catching anamolies in a match.


## FAQ

`Q`. Do game managers know the outcome of a match?

`A`. All games are live and real time, and the final game outcome cannot be determined by anyone until game has concluded.


`Q`. Can the game manager fake data to rig the outcomes?

`A`. Validators ensures the integrity of the data on which outcomes are being decided.

`Q`. Can Game Managers start an already played game as a new game where they know the outcome and bet in their favour?

`A`. logHash and validators prevent such cases. If a game has already been played, then its trivial to find similarity between the real time logs to that of an existing game.
If the logs of a game are similar to a previously played game, game will be challenged by the validator.

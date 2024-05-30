# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```

- deposit on every tx
- live games only, with live odds
- at game start, startMatch is called with number of players, and multiplier, and matchId
- at game end, settleMatch is called with result playerId and log hash
- contract settles the bets placed according to winning playerId
- multiplierHashSig for live odds
- challenge match logs

const hre = require("hardhat");

const abi =
  require("../artifacts/contracts/XtremeGambleFi.sol/XtremeGambleFi.json").abi;
const gambleFiContract = require("./constants.json").gambleFiContract;

const getMultiplierSignature =
  require("./getMultiplierSignature").getMultiplierSignature;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("account:", deployer.address);

  // contract with owner account
  let contractOwner = new ethers.Contract(gambleFiContract, abi, deployer);

  let better1privatekey =
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
  let betterWallet = new ethers.Wallet(better1privatekey, ethers.provider);
  // contract with betting player account
  let contractBetter = new ethers.Contract(gambleFiContract, abi, betterWallet);

  console.log("match flow");

  let empty32bytes = ethers.ZeroHash;

  await contractOwner.startGame(1, 120);

  let multiplierSig = await getMultiplierSignature(1, 1, 120);

  await contractBetter.depositAndBet(
    ethers.parseEther("0.1"),
    1,
    1,
    120,
    multiplierSig,
    { value: ethers.parseEther("0.1") }
  );

  await contractOwner.endAndSettleGame(1, 1, empty32bytes);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

const hre = require("hardhat");

const abi = require('../artifacts/contracts/XtremeGambleFi.sol/XtremeGambleFi.json').abi

const gambleFiContract = require("./constants.json").gambleFiContract;


async function main() {

  const [deployer] = await ethers.getSigners(); 
  console.log("account:", deployer.address); 

  let contract = new ethers.Contract(gambleFiContract, abi, deployer);
 
  console.log("validating data");
  console.log((await contract.matches(1)).toString())
  console.log((await contract.balances('0x70997970C51812dc3A010C7d01b50e0d17dc79C8')).toString())

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
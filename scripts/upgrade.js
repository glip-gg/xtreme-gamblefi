const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

const abi = require('../artifacts/contracts/XtremeGambleFi.sol/XtremeGambleFi.json').abi
const gambleFiContract = require("./constants.json").gambleFiContract;

async function main() {

  const [deployer] = await ethers.getSigners(); 
  console.log("Deploying contracts with the account:", deployer.address); 

  const XtremeV2Factory = await ethers.getContractFactory("XtremeGambleFi");
  const XtremeV2 = await upgrades.upgradeProxy(gambleFiContract, XtremeV2Factory);
  
  console.log("Box upgraded");

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
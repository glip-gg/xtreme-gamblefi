const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

const abi = require('../artifacts/contracts/XtremeGambleFi.sol/XtremeGambleFi.json').abi

async function main() {

  const [deployer] = await ethers.getSigners(); 
  console.log("Deploying contracts with the account:", deployer.address); 

  let blastPointsTestnetAddress = '0x2fc95838c71e76ec69ff817983BFf17c710F34E0'
  let blastPointsMainnetAddress = '0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800'

  console.log('deploying xtreme gamblefi')

  const xtremeGambleFactory = await hre.ethers.getContractFactory('XtremeGambleFi');
  const xtremeGambleContract = await upgrades.deployProxy(xtremeGambleFactory, [blastPointsTestnetAddress]);
  let deployed = await xtremeGambleContract.waitForDeployment();
  
  console.log("xtreme gamblefi deployed to:", deployed.target);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
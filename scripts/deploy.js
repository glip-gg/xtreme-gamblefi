const hre = require("hardhat");

const abi = require('../artifacts/contracts/XtremeGambleFi.sol/XtremeGambleFi.json').abi

async function main() {

  const [deployer] = await ethers.getSigners(); 
  console.log("Deploying contracts with the account:", deployer.address); 

  console.log('deploying xtreme gamblefi')
  const xtremeGambleFactory = await hre.ethers.getContractFactory('XtremeGambleFi');
  const xtremeGambleContract = await xtremeGambleFactory.deploy();
  let deployed = await xtremeGambleContract.waitForDeployment();
  
  console.log("xtreme gamblefi deployed to:", deployed.target);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
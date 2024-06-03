const hre = require("hardhat");

const abi = hre.ethers.AbiCoder.defaultAbiCoder();

const gambleFiContract = require("./constants.json").gambleFiContract;

let getMultiplierSignature = async function (matchId, playerId, multiplier) {

   // sign the message, abi.encode(matchId, playerId, multiplier)

    const [deployer] = await ethers.getSigners();

    const params = ethers.keccak256(abi.encode(
        ["uint", "uint8", "uint16"], 
        [ matchId, playerId, multiplier]));

   let message = await deployer.signMessage(Buffer.from(params.slice(2), 'hex'));

   console.log("multiplier signature:", message);

   return message;

    
}

module.exports = {
    getMultiplierSignature,
}
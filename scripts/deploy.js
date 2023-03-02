const { network, ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  const factory = await ethers.getContractFactory("Will");
  const contract = await factory.deploy(100);
  await contract.deployed();
  console.log(`this contract deployed to ${contract.address}`);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

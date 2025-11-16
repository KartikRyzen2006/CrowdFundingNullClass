const hre = require("hardhat");

async function main() {
  const CrowdArgus = await hre.ethers.getContractFactory("CrowdArgus");
  console.log("Deploying CrowdArgus…");
  const crowdArgus = await CrowdArgus.deploy();

  await crowdArgus.waitForDeployment();          // Hardhat v3 style
  const address = crowdArgus.target;             // Hardhat v3 style
  console.log("CrowdArgus deployed to:", address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
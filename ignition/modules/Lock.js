async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const MetaXSeed = await ethers.getContractFactory("MetaXSeed");
  const metaXSeed = await MetaXSeed.deploy("MetaXSeed", "MTX", deployer.address, deployer.address, 10);

  await metaXSeed.deployed();

  console.log("MetaXSeed deployed to:", metaXSeed.address);

  // Wait for a few blocks to be mined before verifying
  await delay(60000);  // Delay for 60 seconds

  // Verify the contract on Etherscan
  await hre.run("verify:verify", {
      address: metaXSeed.address,
      constructorArguments: [
          "MetaXSeed",
          "MTX",
          deployer.address,
          deployer.address,
          10
      ]
  });
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
      console.error(error);
      process.exit(1);
  });

const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  // Optional: deploy LiquidityManager if it exists and needs no params
  let lmAddr = "";
  try {
    const LM = await ethers.getContractFactory("LiquidityManager");
    const lm = await LM.deploy();
    await lm.deployed();
    lmAddr = lm.address;
    console.log("LiquidityManager:", lmAddr);
  } catch (e) {
    console.log("LiquidityManager not deployed (constructor mismatch or missing). Skipped.");
  }

  const Dex = await ethers.getContractFactory("DecentralizedExchange");
  const dex = await Dex.deploy();
  await dex.deployed();

  console.log("DecentralizedExchange:", dex.address);

  const out = {
    network: hre.network.name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    contracts: {
      LiquidityManager: lmAddr || null,
      DecentralizedExchange: dex.address
    }
  };

  const outPath = path.join(__dirname, "..", "deployments.json");
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log("Saved:", outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});


const fs = require("fs");
const path = require("path");

async function main() {
  const depPath = path.join(__dirname, "..", "deployments.json");
  const deployments = JSON.parse(fs.readFileSync(depPath, "utf8"));

  const dexAddr = deployments.contracts.DecentralizedExchange;
  const dex = await ethers.getContractAt("DecentralizedExchange", dexAddr);

  console.log("DEX:", dexAddr);
  console.log("Smoke: getAmountOut(1000, 100000, 50000) =", (await dex.getAmountOut(1000, 100000, 50000)).toString());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});


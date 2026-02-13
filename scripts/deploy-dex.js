
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Base Decentralized Exchange...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Деплой токенов
  const Token1 = await ethers.getContractFactory("ERC20Token");
  const token1 = await Token1.deploy("Token1", "TKN1");
  await token1.deployed();
  
  const Token2 = await ethers.getContractFactory("ERC20Token");
  const token2 = await Token2.deploy("Token2", "TKN2");
  await token2.deployed();

  // Деплой DEX контракта
  const DecentralizedExchange = await ethers.getContractFactory("DecentralizedExchangeV2");
  const dex = await DecentralizedExchange.deploy();

  await dex.deployed();

  console.log("Base Decentralized Exchange deployed to:", dex.address);
  console.log("Token1 deployed to:", token1.address);
  console.log("Token2 deployed to:", token2.address);
  
  // Сохраняем адреса
  const fs = require("fs");
  const data = {
    dex: dex.address,
    token1: token1.address,
    token2: token2.address,
    owner: deployer.address
  };
  
  fs.writeFileSync("./config/deployment.json", JSON.stringify(data, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

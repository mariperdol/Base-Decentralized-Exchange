// base-dex/test/dex.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Base Decentralized Exchange", function () {
  let dex;
  let token1;
  let token2;
  let owner;
  let addr1;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    
    // Деплой токенов
    const Token1 = await ethers.getContractFactory("ERC20Token");
    token1 = await Token1.deploy("Token1", "TKN1");
    await token1.deployed();
    
    const Token2 = await ethers.getContractFactory("ERC20Token");
    token2 = await Token2.deploy("Token2", "TKN2");
    await token2.deployed();
    
    // Деплой DEX
    const DecentralizedExchange = await ethers.getContractFactory("DecentralizedExchangeV2");
    dex = await DecentralizedExchange.deploy();
    await dex.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await dex.owner()).to.equal(owner.address);
    });
  });

  describe("Pool Creation", function () {
    it("Should create a pair", async function () {
      await expect(dex.createPair(
        token1.address,
        token2.address,
        30, // 0.3% fee
        0, // Classic pool type
        0  // Fee tier 0
      )).to.emit(dex, "PairCreated");
    });
  });

  describe("Liquidity Operations", function () {
    beforeEach(async function () {
      await dex.createPair(
        token1.address,
        token2.address,
        30, // 0.3% fee
        0, // Classic pool type
        0  // Fee tier 0
      );
    });

    it("Should add liquidity", async function () {
      await token1.mint(addr1.address, ethers.utils.parseEther("1000"));
      await token2.mint(addr1.address, ethers.utils.parseEther("1000"));
      
      await token1.connect(addr1).approve(dex.address, ethers.utils.parseEther("1000"));
      await token2.connect(addr1).approve(dex.address, ethers.utils.parseEther("1000"));
      
      await expect(dex.connect(addr1).addLiquidity(
        token1.address,
        token2.address,
        ethers.utils.parseEther("100"),
        ethers.utils.parseEther("100"),
        ethers.utils.parseEther("90"),
        ethers.utils.parseEther("90"),
        Math.floor(Date.now() / 1000) + 3600
      )).to.emit(dex, "LiquidityAdded");
    });
  });

  describe("Swapping", function () {
    beforeEach(async function () {
      await dex.createPair(
        token1.address,
        token2.address,
        30, // 0.3% fee
        0, // Classic pool type
        0  // Fee tier 0
      );
    });

    it("Should swap tokens", async function () {
      await token1.mint(addr1.address, ethers.utils.parseEther("1000"));
      await token1.connect(addr1).approve(dex.address, ethers.utils.parseEther("1000"));
      
      await expect(dex.connect(addr1).swap(
        token1.address,
        token2.address,
        ethers.utils.parseEther("10"),
        ethers.utils.parseEther("1"),
        addr1.address,
        Math.floor(Date.now() / 1000) + 3600
      )).to.emit(dex, "Swap");
    });
  });
});

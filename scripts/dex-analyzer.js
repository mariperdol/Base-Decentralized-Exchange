// base-dex/scripts/analyzer.js
const { ethers } = require("hardhat");

async function analyzeDEX() {
  console.log("Analyzing Base Decentralized Exchange...");
  
  const dexAddress = "0x...";
  const dex = await ethers.getContractAt("DecentralizedExchangeV2", dexAddress);
  
  // Получение общей статистики
  const exchangeStats = await dex.getExchangeStats();
  console.log("Exchange Stats:", {
    totalVolume: exchangeStats.totalVolume.toString(),
    totalTrades: exchangeStats.totalTrades.toString(),
    totalLiquidity: exchangeStats.totalLiquidity.toString(),
    totalFeesCollected: exchangeStats.totalFeesCollected.toString(),
    totalUsers: exchangeStats.totalUsers.toString()
  });
  
  // Получение информации о пулах
  const poolStats = await dex.getPoolStats();
  console.log("Pool Stats:", {
    totalPools: poolStats.totalPools.toString(),
    activePools: poolStats.activePools.toString(),
    totalLiquidity: poolStats.totalLiquidity.toString()
  });
  
  // Анализ объемов
  const volume24h = await dex.getVolume24h();
  console.log("24h Volume:", volume24h.toString());
  
  // Анализ токенов
  const tokenStats = await dex.getTokenStats();
  console.log("Token Stats:", {
    totalTokens: tokenStats.totalTokens.toString(),
    activeTokens: tokenStats.activeTokens.toString()
  });
  
  // Генерация аналитического отчета
  const fs = require("fs");
  const analysis = {
    timestamp: new Date().toISOString(),
    dexAddress: dexAddress,
    analysis: {
      exchangeStats: exchangeStats,
      poolStats: poolStats,
      volume24h: volume24h.toString(),
      tokenStats: tokenStats
    }
  };
  
  fs.writeFileSync("./reports/dex-analysis.json", JSON.stringify(analysis, null, 2));
  
  console.log("DEX analysis completed successfully!");
}

analyzeDEX()
  .catch(error => {
    console.error("Analysis error:", error);
    process.exit(1);
  });

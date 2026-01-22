// base-dex/scripts/liquidity-monitor.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function monitorDEXLiquidity() {
  console.log("Monitoring Base Decentralized Exchange liquidity...");
  
  const dexAddress = "0x...";
  const dex = await ethers.getContractAt("DecentralizedExchangeV2", dexAddress);

  const pools = await dex.getAllPools();
  console.log("Number of pools:", pools.length);
  
  // Мониторинг ликвидности
  const liquidityData = [];
  
  for (let i = 0; i < pools.length; i++) {
    const poolAddress = pools[i];
    const poolInfo = await dex.getPoolInfo(poolAddress);
    
    const liquidity = await dex.getPoolLiquidity(poolAddress);
    
    liquidityData.push({
      poolAddress: poolAddress,
      token1: poolInfo.token1,
      token2: poolInfo.token2,
      reserve1: poolInfo.reserve1.toString(),
      reserve2: poolInfo.reserve2.toString(),
      liquidityDepth: liquidity.liquidityDepth.toString(),
      tvl: liquidity.tvl.toString(),
      liquidityRatio: liquidity.liquidityRatio.toString()
    });
  }
  
  // Анализ ликвидности
  const totalTVL = liquidityData.reduce((sum, pool) => sum + parseInt(pool.tvl), 0);
  const avgLiquidityRatio = liquidityData.reduce((sum, pool) => sum + parseInt(pool.liquidityRatio), 0) / liquidityData.length;
  
  // Создание отчета
  const liquidityReport = {
    timestamp: new Date().toISOString(),
    dexAddress: dexAddress,
    pools: liquidityData,
    totalTVL: totalTVL.toString(),
    avgLiquidityRatio: avgLiquidityRatio.toString(),
    liquidityAlerts: [],
    recommendations: []
  };
  
  // Проверка на проблемы ликвидности
  liquidityData.forEach(pool => {
    if (parseInt(pool.liquidityRatio) < 80) {
      liquidityReport.liquidityAlerts.push(`Low liquidity in pool ${pool.poolAddress}`);
    }
    if (parseInt(pool.tvl) < 1000000) {
      liquidityReport.liquidityAlerts.push(`Low TVL in pool ${pool.poolAddress}`);
    }
  });
  
  // Рекомендации
  if (avgLiquidityRatio < 90) {
    liquidityReport.recommendations.push("Add more liquidity to improve trading experience");
  }
  
  if (liquidityReport.liquidityAlerts.length > 0) {
    liquidityReport.recommendations.push("Investigate and resolve liquidity issues");
  }
  
  // Сохранение отчета
  fs.writeFileSync(`./liquidity/liquidity-monitor-${Date.now()}.json`, JSON.stringify(liquidityReport, null, 2));
  
  console.log("Liquidity monitoring completed successfully!");
  console.log("Alerts:", liquidityReport.liquidityAlerts.length);
}

monitorDEXLiquidity()
  .catch(error => {
    console.error("Liquidity monitoring error:", error);
    process.exit(1);
  });

// base-dex/scripts/user-analytics.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function analyzeDEXUserBehavior() {
  console.log("Analyzing user behavior for Base Decentralized Exchange...");
  
  const dexAddress = "0x...";
  const dex = await ethers.getContractAt("DecentralizedExchangeV2", dexAddress);
  
  // Анализ пользовательского поведения
  const userAnalytics = {
    timestamp: new Date().toISOString(),
    dexAddress: dexAddress,
    userDemographics: {},
    engagementMetrics: {},
    tradingPatterns: {},
    userSegments: {},
    recommendations: []
  };
  
  try {
    // Демография пользователей
    const userDemographics = await dex.getUserDemographics();
    userAnalytics.userDemographics = {
      totalUsers: userDemographics.totalUsers.toString(),
      activeUsers: userDemographics.activeUsers.toString(),
      newUsers: userDemographics.newUsers.toString(),
      returningUsers: userDemographics.returningUsers.toString(),
      userDistribution: userDemographics.userDistribution
    };
    
    // Метрики вовлеченности
    const engagementMetrics = await dex.getEngagementMetrics();
    userAnalytics.engagementMetrics = {
      avgSessionTime: engagementMetrics.avgSessionTime.toString(),
      dailyActiveUsers: engagementMetrics.dailyActiveUsers.toString(),
      weeklyActiveUsers: engagementMetrics.weeklyActiveUsers.toString(),
      monthlyActiveUsers: engagementMetrics.monthlyActiveUsers.toString(),
      userRetention: engagementMetrics.userRetention.toString(),
      engagementScore: engagementMetrics.engagementScore.toString()
    };
    
    // Паттерны торговли
    const tradingPatterns = await dex.getTradingPatterns();
    userAnalytics.tradingPatterns = {
      avgTradeValue: tradingPatterns.avgTradeValue.toString(),
      tradeFrequency: tradingPatterns.tradeFrequency.toString(),
      popularPairs: tradingPatterns.popularPairs,
      peakTradingHours: tradingPatterns.peakTradingHours,
      averageTradeTime: tradingPatterns.averageTradeTime.toString(),
      successRate: tradingPatterns.successRate.toString()
    };
    
    // Сегментация пользователей
    const userSegments = await dex.getUserSegments();
    userAnalytics.userSegments = {
      casualTraders: userSegments.casualTraders.toString(),
      activeTraders: userSegments.activeTraders.toString(),
      professionalTraders: userSegments.professionalTraders.toString(),
      occasionalTraders: userSegments.occasionalTraders.toString(),
      highValueTraders: userSegments.highValueTraders.toString(),
      segmentDistribution: userSegments.segmentDistribution
    };
    
    // Анализ поведения
    if (parseFloat(userAnalytics.engagementMetrics.userRetention) < 70) {
      userAnalytics.recommendations.push("Low user retention - implement retention strategies");
    }
    
    if (parseFloat(userAnalytics.tradingPatterns.successRate) < 90) {
      userAnalytics.recommendations.push("Low trading success rate - optimize trading experience");
    }
    
    if (parseFloat(userAnalytics.userSegments.highValueTraders) < 100) {
      userAnalytics.recommendations.push("Low high-value traders - focus on premium user acquisition");
    }
    
    if (userAnalytics.userSegments.casualTraders > userAnalytics.userSegments.activeTraders) {
      userAnalytics.recommendations.push("More casual traders than active traders - consider trader engagement");
    }
    
    // Сохранение отчета
    const analyticsFileName = `dex-user-analytics-${Date.now()}.json`;
    fs.writeFileSync(`./analytics/${analyticsFileName}`, JSON.stringify(userAnalytics, null, 2));
    console.log(`User analytics report created: ${analyticsFileName}`);
    
    console.log("DEX user analytics completed successfully!");
    console.log("Recommendations:", userAnalytics.recommendations);
    
  } catch (error) {
    console.error("User analytics error:", error);
    throw error;
  }
}

analyzeDEXUserBehavior()
  .catch(error => {
    console.error("User analytics failed:", error);
    process.exit(1);
  });

// base-dex/contracts/DecentralizedExchangeV2.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DecentralizedExchangeV2 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct Pair {
        IERC20 token0;
        IERC20 token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        uint256 fee;
        uint256 lastTradeTime;
        uint256 volume24h;
        uint256 volume7d;
        uint256 liquidityDepth;
        bool isActive;
        uint256 poolType; // 0 = classic, 1 = concentrated, 2 = stable
        uint256 feeTier; // 0 = 0.3%, 1 = 0.5%, 2 = 1%
        uint256 priceImpact;
    }

    struct LiquidityPosition {
        uint256 liquidityAmount;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 lastUpdateTime;
        uint256[] stakingHistory;
        uint256 totalFeesEarned;
        uint256 rewardDebt;
    }

    struct UserTradeHistory {
        uint256[] tradeTimestamps;
        uint256[] tradeAmounts;
        uint256[] tradePrices;
        uint256[] tradeFees;
    }

    struct PoolConfig {
        uint256 minLiquidity;
        uint256 maxLiquidity;
        uint256 minFee;
        uint256 maxFee;
        uint256 maxPriceImpact;
        bool enableStablePools;
        uint256 minTradingVolume;
    }

    struct Trade {
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 fee;
        uint256 timestamp;
        uint256 price;
        uint256 slippage;
        uint256 tradeType; // 0 = swap, 1 = add liquidity, 2 = remove liquidity
    }

    struct FeeCollector {
        address collectorAddress;
        uint256 collectedFees;
        uint256 lastCollectionTime;
        uint256 collectionFrequency;
    }

    mapping(address => mapping(address => Pair)) public pairs;
    mapping(address => mapping(address => LiquidityPosition)) public liquidityPositions;
    mapping(address => UserTradeHistory) public userTradeHistories;
    mapping(address => FeeCollector) public feeCollectors;
    
    PoolConfig public poolConfig;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE = 30; // 0.3%
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant MIN_FEE = 10; // 0.1%
    uint256 public constant MAX_PRICE_IMPACT = 500; // 5%
    uint256 public constant MAX_POOL_TYPE = 2;
    uint256 public constant MAX_FEE_TIER = 2;
    
    // Статистика
    uint256 public totalVolume;
    uint256 public totalTrades;
    uint256 public totalLiquidity;
    uint256 public totalFeesCollected;
    uint256 public totalUsers;
    uint256 public constant MAX_TRADE_HISTORY = 1000;
    
    // События
    event PairCreated(
        address indexed token0,
        address indexed token1,
        uint256 fee,
        uint256 poolType,
        uint256 timestamp
    );
    
    event LiquidityAdded(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted,
        uint256 timestamp
    );
    
    event LiquidityRemoved(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned,
        uint256 timestamp
    );
    
    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        uint256 timestamp
    );
    
    event PoolUpdated(
        address indexed token0,
        address indexed token1,
        uint256 fee,
        uint256 poolType,
        uint256 feeTier,
        uint256 timestamp
    );
    
    event FeeCollected(
        address indexed collector,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    
    event TradeHistoryUpdated(
        address indexed user,
        uint256 tradeIndex,
        uint256 timestamp
    );
    
    event PoolConfigUpdated(
        uint256 minLiquidity,
        uint256 maxLiquidity,
        uint256 minFee,
        uint256 maxFee,
        uint256 maxPriceImpact
    );

    constructor(
        uint256 _minLiquidity,
        uint256 _maxLiquidity,
        uint256 _minFee,
        uint256 _maxFee,
        uint256 _maxPriceImpact
    ) {
        poolConfig = PoolConfig({
            minLiquidity: _minLiquidity,
            maxLiquidity: _maxLiquidity,
            minFee: _minFee,
            maxFee: _maxFee,
            maxPriceImpact: _maxPriceImpact,
            enableStablePools: true,
            minTradingVolume: 1000 // Minimum trading volume threshold
        });
    }

    // Создание нового пула
    function createPair(
        address token0,
        address token1,
        uint256 fee,
        uint256 poolType,
        uint256 feeTier
    ) external onlyOwner {
        require(token0 != token1, "Same tokens");
        require(fee >= MIN_FEE && fee <= MAX_FEE, "Invalid fee");
        require(poolType <= MAX_POOL_TYPE, "Invalid pool type");
        require(feeTier <= MAX_FEE_TIER, "Invalid fee tier");
        
        pairs[token0][token1] = Pair({
            token0: IERC20(token0),
            token1: IERC20(token1),
            reserve0: 0,
            reserve1: 0,
            totalSupply: 0,
            fee: fee,
            lastTradeTime: block.timestamp,
            volume24h: 0,
            volume7d: 0,
            liquidityDepth: 0,
            isActive: true,
            poolType: poolType,
            feeTier: feeTier,
            priceImpact: 0
        });
        
        pairs[token1][token0] = pairs[token0][token1]; // Mirror pair
        
        emit PairCreated(token0, token1, fee, poolType, block.timestamp);
    }

    // Обновление параметров пула
    function updatePool(
        address token0,
        address token1,
        uint256 fee,
        uint256 poolType,
        uint256 feeTier
    ) external onlyOwner {
        Pair storage pair = pairs[token0][token1];
        require(pair.token0 != address(0), "Pair does not exist");
        require(fee >= MIN_FEE && fee <= MAX_FEE, "Invalid fee");
        require(poolType <= MAX_POOL_TYPE, "Invalid pool type");
        require(feeTier <= MAX_FEE_TIER, "Invalid fee tier");
        
        pair.fee = fee;
        pair.poolType = poolType;
        pair.feeTier = feeTier;
        
        emit PoolUpdated(token0, token1, fee, poolType, feeTier, block.timestamp);
    }

    // Включение/отключение пула
    function togglePool(
        address token0,
        address token1
    ) external onlyOwner {
        Pair storage pair = pairs[token0][token1];
        require(pair.token0 != address(0), "Pair does not exist");
        pair.isActive = !pair.isActive;
    }

    // Добавление ликвидности
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external payable nonReentrant {
        require(deadline >= block.timestamp, "Deadline passed");
        require(amount0Desired >= amount0Min && amount1Desired >= amount1Min, "Insufficient liquidity");
        
        Pair storage pair = pairs[token0][token1];
        require(pair.token0 != address(0), "Pair does not exist");
        require(pair.isActive, "Pool inactive");
        
        // Проверка лимитов
        require(amount0Desired >= poolConfig.minLiquidity, "Amount below minimum");
        require(amount0Desired <= poolConfig.maxLiquidity, "Amount above maximum");
        
        // Расчет ликвидности
        uint256 liquidity;
        if (pair.totalSupply == 0) {
            liquidity = sqrt(amount0Desired * amount1Desired);
        } else {
            uint256 liquidity0 = (amount0Desired * pair.totalSupply) / pair.reserve0;
            uint256 liquidity1 = (amount1Desired * pair.totalSupply) / pair.reserve1;
            liquidity = min(liquidity0, liquidity1);
        }
        
        require(liquidity >= amount0Min && liquidity >= amount1Min, "Insufficient liquidity");
        
        // Перевод токенов
        pair.token0.transferFrom(msg.sender, address(this), amount0Desired);
        pair.token1.transferFrom(msg.sender, address(this), amount1Desired);
        
        // Обновление резервов
        pair.reserve0 += amount0Desired;
        pair.reserve1 += amount1Desired;
        pair.totalSupply += liquidity;
        pair.liquidityDepth = pair.liquidityDepth.add(liquidity);
        
        // Mint ликвидности пользователю
        liquidityPositions[msg.sender][token0].liquidityAmount += liquidity;
        liquidityPositions[msg.sender][token0].token0Amount += amount0Desired;
        liquidityPositions[msg.sender][token0].token1Amount += amount1Desired;
        
        // Обновление статистики
        totalLiquidity = totalLiquidity.add(liquidity);
        totalUsers = totalUsers.add(1);
        
        emit LiquidityAdded(msg.sender, token0, token1, amount0Desired, amount1Desired, liquidity, block.timestamp);
    }

    // Удаление ликвидности
    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external payable nonReentrant {
        require(deadline >= block.timestamp, "Deadline passed");
        require(liquidity > 0, "Invalid liquidity");
        
        Pair storage pair = pairs[token0][token1];
        require(pair.token0 != address(0), "Pair does not exist");
        require(pair.isActive, "Pool inactive");
        
        // Проверка наличия ликвидности
        require(liquidityPositions[msg.sender][token0].liquidityAmount >= liquidity, "Insufficient liquidity");
        
        // Расчет полученных токенов
        uint256 amount0 = (liquidity * pair.reserve0) / pair.totalSupply;
        uint256 amount1 = (liquidity * pair.reserve1) / pair.totalSupply;
        
        require(amount0 >= amount0Min && amount1 >= amount1Min, "Insufficient output");
        
        // Перевод токенов
        pair.token0.transfer(msg.sender, amount0);
        pair.token1.transfer(msg.sender, amount1);
        
        // Обновление резервов
        pair.reserve0 = pair.reserve0.sub(amount0);
        pair.reserve1 = pair.reserve1.sub(amount1);
        pair.totalSupply = pair.totalSupply.sub(liquidity);
        pair.liquidityDepth = pair.liquidityDepth.sub(liquidity);
        
        // Обновление позиции пользователя
        liquidityPositions[msg.sender][token0].liquidityAmount = liquidityPositions[msg.sender][token0].liquidityAmount.sub(liquidity);
        liquidityPositions[msg.sender][token0].token0Amount = liquidityPositions[msg.sender][token0].token0Amount.sub(amount0);
        liquidityPositions[msg.sender][token0].token1Amount = liquidityPositions[msg.sender][token0].token1Amount.sub(amount1);
        
        // Обновление статистики
        totalLiquidity = totalLiquidity.sub(liquidity);
        
        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidity, block.timestamp);
    }

    // Свап токенов
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external payable nonReentrant {
        require(deadline >= block.timestamp, "Deadline passed");
        require(amountIn > 0, "Amount in must be greater than 0");
        require(tokenIn != tokenOut, "Same tokens");
        
        Pair storage pair = pairs[tokenIn][tokenOut];
        require(pair.token0 != address(0), "Pair does not exist");
        require(pair.isActive, "Pool inactive");
        
        // Проверка минимальной суммы
        require(amountIn >= poolConfig.minTradingVolume, "Amount below minimum trading volume");
        
        // Расчет выходной суммы
        uint256 amountOut = calculateSwapOutput(tokenIn, tokenOut, amountIn);
        require(amountOut >= amountOutMin, "Insufficient output amount");
        
        // Проверка влияния цены
        uint256 priceImpact = calculatePriceImpact(tokenIn, tokenOut, amountIn);
        require(priceImpact <= poolConfig.maxPriceImpact, "Price impact too high");
        
        // Перевод входных токенов
        pair.token0.transferFrom(msg.sender, address(this), amountIn);
        
        // Расчет комиссии
        uint256 feeAmount = (amountIn * pair.fee) / FEE_DENOMINATOR;
        uint256 amountAfterFee = amountIn.sub(feeAmount);
        
        // Перевод выходных токенов
        pair.token1.transfer(to, amountOut);
        
        // Перевод комиссии
        if (feeAmount > 0) {
            pair.token0.transfer(owner(), feeAmount);
        }
        
        // Обновление резервов
        pair.reserve0 = pair.reserve0.add(amountAfterFee);
        pair.reserve1 = pair.reserve1.sub(amountOut);
        pair.lastTradeTime = block.timestamp;
        
        // Обновление статистики
        totalVolume = totalVolume.add(amountIn);
        totalTrades = totalTrades.add(1);
        
        // Обновление объема за 24 часа
        updateVolume24h(tokenIn, tokenOut, amountIn);
        
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, feeAmount, block.timestamp);
    }

    // Расчет выходной суммы свапа
    function calculateSwapOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256) {
        Pair storage pair = pairs[tokenIn][tokenOut];
        require(pair.token0 != address(0), "Pair does not exist");
        
        // Формула постоянного продукта
        uint256 amountInWithFee = (amountIn * (FEE_DENOMINATOR - pair.fee)) / FEE_DENOMINATOR;
        uint256 amountOut = (amountInWithFee * pair.reserve1) / (pair.reserve0 + amountInWithFee);
        
        return amountOut;
    }

    // Расчет влияния цены
    function calculatePriceImpact(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256) {
        Pair storage pair = pairs[tokenIn][tokenOut];
        require(pair.token0 != address(0), "Pair does not exist");
        
        // Простой расчет влияния цены
        uint256 priceImpact = (amountIn * 10000) / pair.reserve0;
        return priceImpact;
    }

    // Обновление объема за 24 часа
    function updateVolume24h(
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) internal {
        Pair storage pair = pairs[tokenIn][tokenOut];
        pair.volume24h = pair.volume24h.add(amount);
        
        // Сброс объема за 7 дней если нужно
        if (block.timestamp > pair.lastTradeTime + 7 days) {
            pair.volume7d = pair.volume24h;
            pair.volume24h = 0;
        }
    }

    // Получение информации о пуле
    function getPairInfo(address token0, address token1) external view returns (Pair memory) {
        return pairs[token0][token1];
    }

    // Получение информации о ликвидности пользователя
    function getUserLiquidity(
        address user,
        address token0
    ) external view returns (LiquidityPosition memory) {
        return liquidityPositions[user][token0];
    }

    // Получение информации о свапе
    function getSwapInfo(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (
        uint256 amountOut,
        uint256 fee,
        uint256 priceImpact
    ) {
        Pair storage pair = pairs[tokenIn][tokenOut];
        require(pair.token0 != address(0), "Pair does not exist");
        
        amountOut = calculateSwapOutput(tokenIn, tokenOut, amountIn);
        fee = (amountIn * pair.fee) / FEE_DENOMINATOR;
        priceImpact = calculatePriceImpact(tokenIn, tokenOut, amountIn);
        
        return (amountOut, fee, priceImpact);
    }

    // Получение статистики пула
    function getPoolStats(
        address token0,
        address token1
    ) external view returns (
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint256 volume24h,
        uint256 volume7d,
        uint256 liquidityDepth,
        uint256 fee,
        uint256 priceImpact
    ) {
        Pair storage pair = pairs[token0][token1];
        return (
            pair.reserve0,
            pair.reserve1,
            pair.totalSupply,
            pair.volume24h,
            pair.volume7d,
            pair.liquidityDepth,
            pair.fee,
            pair.priceImpact
        );
    }

    // Получение конфигурации пула
    function getPoolConfig() external view returns (PoolConfig memory) {
        return poolConfig;
    }

    // Получение статистики биржи
    function getExchangeStats() external view returns (
        uint256 totalVolume_,
        uint256 totalTrades_,
        uint256 totalLiquidity_,
        uint256 totalFeesCollected_,
        uint256 totalUsers_
    ) {
        return (
            totalVolume,
            totalTrades,
            totalLiquidity,
            totalFeesCollected,
            totalUsers
        );
    }

    // Получение информации о пользователе
    function getUserInfo(address user) external view returns (
        uint256 totalLiquidity,
        uint256 totalTrades,
        uint256 totalFeesEarned
    ) {
        // Реализация в будущем
        return (0, 0, 0);
    }

    // Получение истории торговли пользователя
    function getUserTradeHistory(address user) external view returns (UserTradeHistory memory) {
        return userTradeHistories[user];
    }

    // Получение всех активных пар
    function getActivePairs() external view returns (address[] memory) {
        // Реализация в будущем
        return new address[](0);
    }

    // Получение списка пулов по типу
    function getPoolsByType(uint256 poolType) external view returns (address[] memory) {
        // Реализация в будущем
        return new address[](0);
    }

    // Получение информации о комиссиях
    function getFeeInfo(
        address token0,
        address token1
    ) external view returns (
        uint256 fee,
        uint256 feeTier,
        uint256 poolType
    ) {
        Pair storage pair = pairs[token0][token1];
        return (pair.fee, pair.feeTier, pair.poolType);
    }

    // Обновление конфигурации пула
    function updatePoolConfig(
        uint256 minLiquidity,
        uint256 maxLiquidity,
        uint256 minFee,
        uint256 maxFee,
        uint256 maxPriceImpact
    ) external onlyOwner {
        require(minLiquidity <= maxLiquidity, "Invalid liquidity limits");
        require(minFee <= maxFee, "Invalid fee limits");
        require(maxPriceImpact <= 10000, "Price impact too high");
        
        poolConfig = PoolConfig({
            minLiquidity: minLiquidity,
            maxLiquidity: maxLiquidity,
            minFee: minFee,
            maxFee: maxFee,
            maxPriceImpact: maxPriceImpact,
            enableStablePools: poolConfig.enableStablePools,
            minTradingVolume: poolConfig.minTradingVolume
        });
        
        emit PoolConfigUpdated(minLiquidity, maxLiquidity, minFee, maxFee, maxPriceImpact);
    }

    // Получение глубины ликвидности
    function getLiquidityDepth(
        address token0,
        address token1
    ) external view returns (uint256) {
        Pair storage pair = pairs[token0][token1];
        return pair.liquidityDepth;
    }

    // Получение максимального влияния цены
    function getMaxPriceImpact() external view returns (uint256) {
        return poolConfig.maxPriceImpact;
    }

    // Получение информации о цене
    function getPriceInfo(
        address token0,
        address token1
    ) external view returns (uint256 price, uint256 timestamp) {
        Pair storage pair = pairs[token0][token1];
        if (pair.reserve0 > 0 && pair.reserve1 > 0) {
            price = pair.reserve1.mul(1e18).div(pair.reserve0);
        }
        timestamp = pair.lastTradeTime;
        return (price, timestamp);
    }

    // Получение всех пулов пользователя
    function getUserPools(address user) external view returns (address[] memory) {
        // Реализация в будущем
        return new address[](0);
    }

    // Получение информации о сборе комиссий
    function getFeeCollector(address collector) external view returns (FeeCollector memory) {
        return feeCollectors[collector];
    }

    // Получение всех активных пулов
    function getActivePools() external view returns (address[] memory) {
        // Реализация в будущем
        return new address[](0);
    }

    // Проверка активности пула
    function isPoolActive(address token0, address token1) external view returns (bool) {
        Pair storage pair = pairs[token0][token1];
        return pair.isActive;
    }

    // Получение общей информации о пуле
    function getPoolOverview(
        address token0,
        address token1
    ) external view returns (
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply,
        uint256 fee,
        uint256 poolType,
        bool isActive,
        uint256 volume24h,
        uint256 liquidityDepth
    ) {
        Pair storage pair = pairs[token0][token1];
        return (
            pair.reserve0,
            pair.reserve1,
            pair.totalSupply,
            pair.fee,
            pair.poolType,
            pair.isActive,
            pair.volume24h,
            pair.liquidityDepth
        );
    }

    // Получение информации о торговле
    function getTradeInfo(
        address trader,
        uint256 tradeIndex
    ) external view returns (Trade memory) {
        // Реализация в будущем
        return Trade({
            trader: address(0),
            tokenIn: address(0),
            tokenOut: address(0),
            amountIn: 0,
            amountOut: 0,
            fee: 0,
            timestamp: 0,
            price: 0,
            slippage: 0,
            tradeType: 0
        });
    }

    // Получение информации о токене
    function getTokenInfo(address token) external view returns (uint256 balance) {
        // Реализация в будущем
        return 0;
    }

    // Получение информации о ликвидности
    function getLiquidityInfo(
        address user,
        address token0,
        address token1
    ) external view returns (
        uint256 liquidityAmount,
        uint256 token0Amount,
        uint256 token1Amount,
        uint256 totalFeesEarned
    ) {
        LiquidityPosition storage position = liquidityPositions[user][token0];
        return (
            position.liquidityAmount,
            position.token0Amount,
            position.token1Amount,
            position.totalFeesEarned
        );
    }

    // Получение общей информации о бирже
    function getExchangeInfo() external view returns (
        uint256 totalVolume_,
        uint256 totalTrades_,
        uint256 totalLiquidity_,
        uint256 totalFeesCollected_,
        uint256 totalUsers_,
        uint256 totalPairs,
        uint256 activePairs
    ) {
        return (
            totalVolume,
            totalTrades,
            totalLiquidity,
            totalFeesCollected,
            totalUsers,
            0, // totalPairs (реализация в будущем)
            0  // activePairs (реализация в будущем)
        );
    }

    // Получение максимальной комиссии
    function getMaxFee() external view returns (uint256) {
        return poolConfig.maxFee;
    }

    // Получение минимальной комиссии
    function getMinFee() external view returns (uint256) {
        return poolConfig.minFee;
    }

    // Получение информации о минимальном объеме
    function getMinTradingVolume() external view returns (uint256) {
        return poolConfig.minTradingVolume;
    }

    // Получение информации о максимальном влиянии цены
    function getMaxPriceImpactAllowed() external view returns (uint256) {
        return poolConfig.maxPriceImpact;
    }

    // Получение информации о типах пулов
    function getPoolTypes() external pure returns (uint256[] memory) {
        uint256[] memory types = new uint256[](3);
        types[0] = 0; // Classic
        types[1] = 1; // Concentrated
        types[2] = 2; // Stable
        return types;
    }

    // Получение информации о тарифах
    function getFeeTiers() external pure returns (uint256[] memory) {
        uint256[] memory tiers = new uint256[](3);
        tiers[0] = 0; // 0.3%
        tiers[1] = 1; // 0.5%
        tiers[2] = 2; // 1%
        return tiers;
    }

    // Проверка правильности sqrt
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (z + x / z) / 2;
        }
        return y;
    }

    // Проверка правильности min
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

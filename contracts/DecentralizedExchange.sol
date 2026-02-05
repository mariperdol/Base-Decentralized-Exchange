# base-dex/contracts/DecentralizedExchange.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedExchange is Ownable {
    struct Pair {
        IERC20 token0;
        IERC20 token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalSupply;
        uint256 fee;
    }
    
    struct LiquidityPosition {
        uint256 liquidityAmount;
        uint256 token0Amount;
        uint256 token1Amount;
        uint256 lastUpdateTime;
    }
    
    mapping(address => mapping(address => Pair)) public pairs;
    mapping(address => mapping(address => LiquidityPosition)) public liquidityPositions;
    
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE = 30; // 0.3%
    
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event LiquidityAdded(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );
    
    event LiquidityRemoved(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned
    );
    
    constructor() {
        // Initialize core tokens
    }
    
    function createPair(
        address token0,
        address token1,
        uint256 fee
    ) external {
        require(token0 != token1, "Same tokens");
        require(fee < FEE_DENOMINATOR, "Invalid fee");
        
        pairs[token0][token1] = Pair({
            token0: IERC20(token0),
            token1: IERC20(token1),
            reserve0: 0,
            reserve1: 0,
            totalSupply: 0,
            fee: fee
        });
        
        pairs[token1][token0] = pairs[token0][token1]; // Mirror pair
    }
    
    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external {
        Pair storage pair = pairs[token0][token1];
        require(pair.token0 != address(0), "Pair does not exist");
        
        // Calculate liquidity based on reserves
        uint256 liquidity;
        if (pair.totalSupply == 0) {
            liquidity = sqrt(amount0Desired * amount1Desired);
        } else {
            uint256 liquidity0 = (amount0Desired * pair.totalSupply) / pair.reserve0;
            uint256 liquidity1 = (amount1Desired * pair.totalSupply) / pair.reserve1;
            liquidity = min(liquidity0, liquidity1);
        }
        
        require(liquidity >= amount0Min && liquidity >= amount1Min, "Insufficient liquidity");
        
        // Transfer tokens to contract
        pair.token0.transferFrom(msg.sender, address(this), amount0Desired);
        pair.token1.transferFrom(msg.sender, address(this), amount1Desired);
        
        // Update reserves
        pair.reserve0 += amount0Desired;
        pair.reserve1 += amount1Desired;
        pair.totalSupply += liquidity;
        
        // Mint liquidity tokens to user
        emit LiquidityAdded(msg.sender, token0, token1, amount0Desired, amount1Desired, liquidity);
    }
    
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external {
        Pair storage pair = pairs[tokenIn][tokenOut];
        require(pair.token0 != address(0), "Pair does not exist");
        
        // Calculate amount out using constant product formula
        uint256 amountInWithFee = (amountIn * (FEE_DENOMINATOR - pair.fee)) / FEE_DENOMINATOR;
        uint256 amountOut = (amountInWithFee * pair.reserve1) / (pair.reserve0 + amountInWithFee);
        
        require(amountOut >= amountOutMin, "Insufficient output amount");
        
        // Transfer tokens
        pair.token0.transferFrom(msg.sender, address(this), amountIn);
        pair.token1.transfer(msg.sender, amountOut);
        
        // Update reserves
        pair.reserve0 += amountIn;
        pair.reserve1 -= amountOut;
        
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
    
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        Pair storage pair = pairs[tokenIn][tokenOut];
        require(pair.token0 != address(0), "Pair does not exist");
        
        uint256 amountInWithFee = (amountIn * (FEE_DENOMINATOR - pair.fee)) / FEE_DENOMINATOR;
        return (amountInWithFee * pair.reserve1) / (pair.reserve0 + amountInWithFee);
    }
    
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
    
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

struct PriceFeed {
    address token;
    uint256 lastPrice;
    uint256 timestamp;
    uint256 priceChange24h;
    uint256 volume24h;
    uint256 liquidity;
    bool enabled;
}

struct AutoPriceUpdate {
    address token;
    uint256 updateFrequency;
    uint256 lastUpdateTime;
    uint256 priceDeviationThreshold;
    bool enabled;
    string source;
}


mapping(address => PriceFeed) public priceFeeds;
mapping(address => AutoPriceUpdate) public autoPriceUpdates;


event PriceFeedUpdated(
    address indexed token,
    uint256 newPrice,
    uint256 timestamp,
    uint256 change24h
);

event AutoPriceUpdateEnabled(
    address indexed token,
    uint256 frequency,
    uint256 deviationThreshold,
    bool enabled
);

event PriceUpdatedAutomatically(
    address indexed token,
    uint256 oldPrice,
    uint256 newPrice,
    uint256 timestamp
);

// Добавить функции:
function updatePriceFeed(
    address token,
    uint256 price,
    uint256 volume24h,
    uint256 liquidity
) external {
    require(price > 0, "Price must be greater than 0");
    
    PriceFeed storage feed = priceFeeds[token];
    uint256 oldPrice = feed.lastPrice;
    
    feed.lastPrice = price;
    feed.timestamp = block.timestamp;
    feed.volume24h = volume24h;
    feed.liquidity = liquidity;
    feed.enabled = true;
    
    // Calculate 24h change
    if (feed.timestamp > block.timestamp - 86400) {
        feed.priceChange24h = ((price - oldPrice) * 10000) / oldPrice;
    }
    
    emit PriceFeedUpdated(token, price, block.timestamp, feed.priceChange24h);
}

function enableAutoPriceUpdate(
    address token,
    uint256 frequency,
    uint256 deviationThreshold,
    string memory source
) external onlyOwner {
    require(frequency >= 300, "Frequency too short (minimum 5 minutes)");
    require(deviationThreshold <= 10000, "Deviation threshold too high");
    
    autoPriceUpdates[token] = AutoPriceUpdate({
        token: token,
        updateFrequency: frequency,
        lastUpdateTime: block.timestamp,
        priceDeviationThreshold: deviationThreshold,
        enabled: true,
        source: source
    });
    
    emit AutoPriceUpdateEnabled(token, frequency, deviationThreshold, true);
}

function disableAutoPriceUpdate(address token) external onlyOwner {
    autoPriceUpdates[token].enabled = false;
    emit AutoPriceUpdateEnabled(token, 0, 0, false);
}

function updatePricesAutomatically() external {
    // Iterate through all tokens with auto-update enabled
    for (uint256 i = 0; i < 100; i++) { // Simplified loop
        address token = address(i);
        AutoPriceUpdate storage update = autoPriceUpdates[token];
        
        if (update.enabled && 
            block.timestamp >= update.lastUpdateTime + update.updateFrequency) {
            
            // Get new price from external source (simplified)
            uint256 newPrice = getExternalPrice(token);
            
            // Check deviation
            PriceFeed storage feed = priceFeeds[token];
            if (feed.lastPrice > 0) {
                uint256 deviation = (abs(newPrice - feed.lastPrice) * 10000) / feed.lastPrice;
                
                if (deviation >= update.priceDeviationThreshold) {
                    // Update price
                    feed.lastPrice = newPrice;
                    feed.timestamp = block.timestamp;
                    
                    emit PriceUpdatedAutomatically(token, feed.lastPrice, newPrice, block.timestamp);
                }
            }
            
            update.lastUpdateTime = block.timestamp;
        }
    }
}

function getExternalPrice(address token) internal view returns (uint256) {
    // Simplified - would connect to external APIs in real implementation
    return 1000000000000000000; // 1 ETH
}

function abs(int256 a) internal pure returns (uint256) {
    return a >= 0 ? uint256(a) : uint256(-a);
}

function getPriceFeed(address token) external view returns (PriceFeed memory) {
    return priceFeeds[token];
}

function getAutoPriceUpdate(address token) external view returns (AutoPriceUpdate memory) {
    return autoPriceUpdates[token];
}

function getMarketStats() external view returns (
    uint256 totalVolume,
    uint256 totalLiquidity,
    uint256 activeTokens,
    uint256 avgPriceChange24h
) {
    // Implementation would return market statistics
    return (0, 0, 0, 0);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DecentralizedExchange is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // Существующие структуры и функции...
    
    // Новые структуры для сложных ордеров
    struct LimitOrder {
        uint256 orderId;
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 price;
        uint256 expiration;
        bool active;
        uint256 timestamp;
        uint256 orderType; // 0: limit, 1: stop-loss, 2: take-profit
        uint256 stopPrice;
        uint256 trailingStop;
        uint256 slippage;
        string orderTag;
        uint256 fee;
        uint256 filledAmount;
        uint256 remainingAmount;
        mapping(address => bool) filledBy;
    }
    
    struct StopLossOrder {
        uint256 orderId;
        address trader;
        address token;
        uint256 amount;
        uint256 stopPrice;
        uint256 triggerPrice;
        uint256 expiration;
        bool active;
        uint256 timestamp;
        uint256 fee;
        uint256 slippage;
        string description;
    }
    
    struct TakeProfitOrder {
        uint256 orderId;
        address trader;
        address token;
        uint256 amount;
        uint256 profitTarget;
        uint256 triggerPrice;
        uint256 expiration;
        bool active;
        uint256 timestamp;
        uint256 fee;
        uint256 slippage;
        string description;
    }
    
    struct OrderBook {
        address tokenA;
        address tokenB;
        uint256[] bidPrices;
        uint256[] bidAmounts;
        uint256[] askPrices;
        uint256[] askAmounts;
        uint256 lastUpdate;
        uint256[] activeOrders;
    }
    
    struct MarketMaker {
        address maker;
        address[] tokens;
        uint256[] liquidityAmounts;
        uint256 fee;
        uint256 spread;
        uint256 maxPosition;
        uint256 lastUpdate;
        bool active;
    }
    
    // Новые маппинги
    mapping(uint256 => LimitOrder) public limitOrders;
    mapping(uint256 => StopLossOrder) public stopLossOrders;
    mapping(uint256 => TakeProfitOrder) public takeProfitOrders;
    mapping(address => mapping(address => OrderBook)) public orderBooks;
    mapping(address => MarketMaker) public marketMakers;
    mapping(address => uint256[]) public userOrders;
    mapping(uint256 => bool) public orderExecuted;
    
    // Новые события
    event LimitOrderCreated(
        uint256 indexed orderId,
        address indexed trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 price,
        uint256 expiration,
        uint256 orderType,
        string orderTag
    );
    
    event LimitOrderExecuted(
        uint256 indexed orderId,
        address indexed trader,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        uint256 timestamp
    );
    
    event LimitOrderCancelled(
        uint256 indexed orderId,
        address indexed trader,
        uint256 timestamp
    );
    
    event StopLossOrderCreated(
        uint256 indexed orderId,
        address indexed trader,
        address token,
        uint256 amount,
        uint256 stopPrice,
        uint256 expiration,
        uint256 fee,
        string description
    );
    
    event TakeProfitOrderCreated(
        uint256 indexed orderId,
        address indexed trader,
        address token,
        uint256 amount,
        uint256 profitTarget,
        uint256 expiration,
        uint256 fee,
        string description
    );
    
    event OrderBookUpdated(
        address tokenA,
        address tokenB,
        uint256[] bidPrices,
        uint256[] askPrices,
        uint256 timestamp
    );
    
    event MarketMakerAdded(
        address indexed maker,
        address[] tokens,
        uint256[] liquidityAmounts,
        uint256 fee,
        uint256 spread,
        uint256 maxPosition,
        uint256 timestamp
    );
    
    event MarketMakerRemoved(
        address indexed maker,
        uint256 timestamp
    );
    
    // Новые функции для сложных ордеров
    function createLimitOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 price,
        uint256 expiration,
        uint256 orderType,
        string memory orderTag,
        uint256 slippage
    ) external {
        require(tokenIn != tokenOut, "Same tokens");
        require(amountIn > 0, "Amount must be greater than 0");
        require(price > 0, "Price must be greater than 0");
        require(expiration > block.timestamp, "Expiration must be in future");
        require(slippage <= 10000, "Slippage too high");
        
        uint256 orderId = uint256(keccak256(abi.encodePacked(tokenIn, tokenOut, amountIn, block.timestamp)));
        
        limitOrders[orderId] = LimitOrder({
            orderId: orderId,
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            price: price,
            expiration: expiration,
            active: true,
            timestamp: block.timestamp,
            orderType: orderType,
            stopPrice: 0,
            trailingStop: 0,
            slippage: slippage,
            orderTag: orderTag,
            fee: 0, // Комиссия будет рассчитана при исполнении
            filledAmount: 0,
            remainingAmount: amountIn,
            filledBy: new mapping(address => bool)
        });
        
        // Добавить в список пользователя
        userOrders[msg.sender].push(orderId);
        
        // Обновить книгу ордеров
        updateOrderBook(tokenIn, tokenOut, orderId, true);
        
        emit LimitOrderCreated(
            orderId,
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            price,
            expiration,
            orderType,
            orderTag
        );
    }
    
    function createStopLossOrder(
        address token,
        uint256 amount,
        uint256 stopPrice,
        uint256 triggerPrice,
        uint256 expiration,
        uint256 slippage,
        string memory description
    ) external {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be greater than 0");
        require(stopPrice > 0, "Stop price must be greater than 0");
        require(triggerPrice > 0, "Trigger price must be greater than 0");
        require(expiration > block.timestamp, "Expiration must be in future");
        require(slippage <= 10000, "Slippage too high");
        
        uint256 orderId = uint256(keccak256(abi.encodePacked(token, amount, stopPrice, block.timestamp)));
        
        stopLossOrders[orderId] = StopLossOrder({
            orderId: orderId,
            trader: msg.sender,
            token: token,
            amount: amount,
            stopPrice: stopPrice,
            triggerPrice: triggerPrice,
            expiration: expiration,
            active: true,
            timestamp: block.timestamp,
            fee: 0,
            slippage: slippage,
            description: description
        });
        
        // Добавить в список пользователя
        userOrders[msg.sender].push(orderId);
        
        emit StopLossOrderCreated(
            orderId,
            msg.sender,
            token,
            amount,
            stopPrice,
            expiration,
            0,
            description
        );
    }
    
    function createTakeProfitOrder(
        address token,
        uint256 amount,
        uint256 profitTarget,
        uint256 triggerPrice,
        uint256 expiration,
        uint256 slippage,
        string memory description
    ) external {
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be greater than 0");
        require(profitTarget > 0, "Profit target must be greater than 0");
        require(triggerPrice > 0, "Trigger price must be greater than 0");
        require(expiration > block.timestamp, "Expiration must be in future");
        require(slippage <= 10000, "Slippage too high");
        
        uint256 orderId = uint256(keccak256(abi.encodePacked(token, amount, profitTarget, block.timestamp)));
        
        takeProfitOrders[orderId] = TakeProfitOrder({
            orderId: orderId,
            trader: msg.sender,
            token: token,
            amount: amount,
            profitTarget: profitTarget,
            triggerPrice: triggerPrice,
            expiration: expiration,
            active: true,
            timestamp: block.timestamp,
            fee: 0,
            slippage: slippage,
            description: description
        });
        
        // Добавить в список пользователя
        userOrders[msg.sender].push(orderId);
        
        emit TakeProfitOrderCreated(
            orderId,
            msg.sender,
            token,
            amount,
            profitTarget,
            expiration,
            0,
            description
        );
    }
    
    function executeLimitOrder(
        uint256 orderId,
        uint256 amountIn
    ) external {
        LimitOrder storage order = limitOrders[orderId];
        require(order.active, "Order not active");
        require(block.timestamp <= order.expiration, "Order expired");
        require(order.trader != msg.sender, "Cannot execute own order");
        require(amountIn > 0, "Amount must be greater than 0");
        require(amountIn <= order.remainingAmount, "Amount exceeds remaining");
        
        // Проверка цены
        uint256 currentPrice = getCurrentPrice(order.tokenIn, order.tokenOut);
        require(currentPrice >= order.price, "Price condition not met");
        
        // Проверка минимального выхода
        uint256 amountOut = calculateAmountOut(order.tokenIn, order.tokenOut, amountIn, order.price);
        require(amountOut >= order.minAmountOut, "Amount below minimum");
        
        // Выполнить обмен
        uint256 fee = amountIn.mul(30).div(10000); // 0.3% комиссия
        uint256 amountAfterFee = amountIn.sub(fee);
        
        // Передача токенов
        IERC20(order.tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(order.tokenOut).transfer(msg.sender, amountOut);
        
      
        if (fee > 0) {
            IERC20(order.tokenIn).transfer(owner(), fee);
        }
        
        // Обновить ордер
        order.filledAmount = order.filledAmount.add(amountIn);
        order.remainingAmount = order.remainingAmount.sub(amountIn);
        order.filledBy[msg.sender] = true;
        
        // Завершить ордер если полностью исполнен
        if (order.remainingAmount == 0) {
            order.active = false;
        }
        
        emit LimitOrderExecuted(
            orderId,
            msg.sender,
            amountIn,
            amountOut,
            fee,
            block.timestamp
        );
    }
    
    function cancelLimitOrder(uint256 orderId) external {
        LimitOrder storage order = limitOrders[orderId];
        require(order.active, "Order not active");
        require(order.trader == msg.sender, "Not order owner");
        
        order.active = false;
        
        // Обновить книгу ордеров
        updateOrderBook(order.tokenIn, order.tokenOut, orderId, false);
        
        emit LimitOrderCancelled(orderId, msg.sender, block.timestamp);
    }
    
    function updateOrderBook(
        address tokenA,
        address tokenB,
        uint256 orderId,
        bool addOrder
    ) internal {
        OrderBook storage book = orderBooks[tokenA][tokenB];
        book.lastUpdate = block.timestamp;
        
        // В реальной реализации здесь будет логика обновления книги ордеров
        // Для демонстрации просто обновляем метку времени
        
        emit OrderBookUpdated(tokenA, tokenB, new uint256[](0), new uint256[](0), block.timestamp);
    }
    
    function addMarketMaker(
        address[] memory tokens,
        uint256[] memory liquidityAmounts,
        uint256 fee,
        uint256 spread,
        uint256 maxPosition
    ) external {
        require(tokens.length == liquidityAmounts.length, "Array length mismatch");
        require(fee <= 10000, "Fee too high");
        require(spread <= 10000, "Spread too high");
        require(maxPosition > 0, "Max position must be greater than 0");
        
        // Проверка, что токены уникальны
        for (uint256 i = 0; i < tokens.length; i++) {
            require(tokens[i] != address(0), "Invalid token");
        }
        
        marketMakers[msg.sender] = MarketMaker({
            maker: msg.sender,
            tokens: tokens,
            liquidityAmounts: liquidityAmounts,
            fee: fee,
            spread: spread,
            maxPosition: maxPosition,
            lastUpdate: block.timestamp,
            active: true
        });
        
        emit MarketMakerAdded(
            msg.sender,
            tokens,
            liquidityAmounts,
            fee,
            spread,
            maxPosition,
            block.timestamp
        );
    }
    
    function removeMarketMaker() external {
        require(marketMakers[msg.sender].maker == msg.sender, "Not market maker");
        
        marketMakers[msg.sender].active = false;
        
        emit MarketMakerRemoved(msg.sender, block.timestamp);
    }
    
    function calculateAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 price
    ) internal view returns (uint256) {
        // Простая реализация - в реальной системе будет сложнее
        return amountIn.mul(price).div(10000);
    }
    
    function getCurrentPrice(
        address tokenIn,
        address tokenOut
    ) internal view returns (uint256) {
        // Простая реализация - в реальной системе будет сложнее
        return 10000; // 1:1 отношение
    }
    
    function getLimitOrderInfo(uint256 orderId) external view returns (LimitOrder memory) {
        return limitOrders[orderId];
    }
    
    function getStopLossOrderInfo(uint256 orderId) external view returns (StopLossOrder memory) {
        return stopLossOrders[orderId];
    }
    
    function getTakeProfitOrderInfo(uint256 orderId) external view returns (TakeProfitOrder memory) {
        return takeProfitOrders[orderId];
    }
    
    function getUserOrders(address user) external view returns (uint256[] memory) {
        return userOrders[user];
    }
    
    function getActiveLimitOrders(
        address tokenIn,
        address tokenOut
    ) external view returns (uint256[] memory) {
        // Возвращает активные ордера для пары токенов
        return new uint256[](0);
    }
    
    function getMarketMakerInfo(address maker) external view returns (MarketMaker memory) {
        return marketMakers[maker];
    }
    
    function getOrderBookInfo(address tokenA, address tokenB) external view returns (OrderBook memory) {
        return orderBooks[tokenA][tokenB];
    }
    
    function getMarketMakerStats() external view returns (
        uint256 totalMarketMakers,
        uint256 activeMarketMakers,
        uint256 totalLiquidity,
        uint256 avgFee,
        uint256 avgSpread
    ) {
        uint256 totalMarketMakersCount = 0;
        uint256 activeMarketMakersCount = 0;
        uint256 totalLiquidityAmount = 0;
        uint256 totalFee = 0;
        uint256 totalSpread = 0;
        
        // Подсчет статистики
        for (uint256 i = 0; i < 100; i++) {
            if (marketMakers[address(i)].maker != address(0)) {
                totalMarketMakersCount++;
                totalLiquidityAmount = totalLiquidityAmount.add(getTotalLiquidity(address(i)));
                totalFee = totalFee.add(marketMakers[address(i)].fee);
                totalSpread = totalSpread.add(marketMakers[address(i)].spread);
                
                if (marketMakers[address(i)].active) {
                    activeMarketMakersCount++;
                }
            }
        }
        
        uint256 avgFeeValue = totalMarketMakersCount > 0 ? totalFee / totalMarketMakersCount : 0;
        uint256 avgSpreadValue = totalMarketMakersCount > 0 ? totalSpread / totalMarketMakersCount : 0;
        
        return (
            totalMarketMakersCount,
            activeMarketMakersCount,
            totalLiquidityAmount,
            avgFeeValue,
            avgSpreadValue
        );
    }
    
    function getTotalLiquidity(address maker) internal view returns (uint256) {
        MarketMaker storage mm = marketMakers[maker];
        uint256 total = 0;
        for (uint256 i = 0; i < mm.liquidityAmounts.length; i++) {
            total = total.add(mm.liquidityAmounts[i]);
        }
        return total;
    }
    
    function getLimitOrderStats() external view returns (
        uint256 totalOrders,
        uint256 activeOrders,
        uint256 executedOrders,
        uint256 avgAmount,
        uint256 avgPrice
    ) {
        uint256 totalOrdersCount = 0;
        uint256 activeOrdersCount = 0;
        uint256 executedOrdersCount = 0;
        uint256 totalAmount = 0;
        uint256 totalPrice = 0;
        
        // Подсчет статистики
        for (uint256 i = 0; i < 10000; i++) {
            if (limitOrders[i].orderId != 0) {
                totalOrdersCount++;
                totalAmount = totalAmount.add(limitOrders[i].amountIn);
                totalPrice = totalPrice.add(limitOrders[i].price);
                
                if (limitOrders[i].active) {
                    activeOrdersCount++;
                } else if (orderExecuted[i]) {
                    executedOrdersCount++;
                }
            }
        }
        
        uint256 avgAmountValue = totalOrdersCount > 0 ? totalAmount / totalOrdersCount : 0;
        uint256 avgPriceValue = totalOrdersCount > 0 ? totalPrice / totalOrdersCount : 0;
        
        return (
            totalOrdersCount,
            activeOrdersCount,
            executedOrdersCount,
            avgAmountValue,
            avgPriceValue
        );
    }
}
}

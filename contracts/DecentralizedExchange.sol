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
    // Добавить структуры:
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

// Добавить маппинги:
mapping(address => PriceFeed) public priceFeeds;
mapping(address => AutoPriceUpdate) public autoPriceUpdates;

// Добавить события:
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
}

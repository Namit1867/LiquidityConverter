# LiquidityConverter

This contract can be use to convert one uniswapv2 LP based token into another uniswapv2 based LP token and give the slippage amount of tokens in the same transaction.

While converting liquidity there can be three cases in other AMM these are:-

## While converting liquidity there can be three cases in other AMM these are:-

- No Pair exist.
- Pair Exist but no liquidity added
- Pair exist and liquidity is greater than 0

In case of **No Pair exist** and **Pair Exist but no liquidity added** pair is added easily and there is no slippage and amount of liquidty added is equal to 

```
amountA = amount of tokenA to be added
amountB = amount of tokenB to be added
a = product of amountA and amountB
b = MINIMUM_LIQUIDITY

liquidity = square root of difference of a and b.
```



But In case **Pair exist and liquidity is greater than 0**
there can be a high slippage while adding the liquidity so we are giving that back in the the same transaction itself

```
amountA = amount of tokenA to be added
amountB = amount of tokenB to be added
reserveA = reserve of tokenA while adding liquidity
reserveB = reserve of tokenB while adding liquidity
totalSupply = total supply of pair token;

a = (amountA * totalSupply) / reserveA
b = (amountB * totalSupply) / reserveB

liquidity = minimum of a and b.

After adding the liquidity same function returns how much tokenA and tokenB amount is added so we take difference from the amount of tokens which we are getting while removing liquidity. 
```

## How to Install and Run

Instructions about how to Install Hardhat and Run the files.

## Installing Hardhat:-
- [Installing Hardhat](https://hardhat.org/getting-started/#installation)

## For Testing

Run the test using this script
```
npx hardhat test
```


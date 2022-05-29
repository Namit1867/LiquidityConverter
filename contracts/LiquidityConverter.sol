// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

}

interface IPancakePair {

    function MINIMUM_LIQUIDITY() external view returns(uint);

    function factory() external view returns(address);

    function totalSupply() external view returns (uint);

    function decimals() external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

interface IPancakeFactory {
    function getPair(address token0, address token1)
        external
        view
        returns (address);
}

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

contract LiquidityConverter is Ownable {
    
    using SafeERC20 for IERC20;

    address public router;
    address public factory;

    uint public constant MINIMUM_LIQUIDITY = 10**3;

    struct WhiteListedRouterData{
        uint index;
        bool isWhiteListed;
    }

    address[] public whitelistedRouters;
    mapping (address => WhiteListedRouterData) public whiteListedRoutersData;

    event LiquidityTransferred(
        address pair,
        address routerAddress,
        uint256 liquidity,
        uint256 finalLiquidity,
        address to
    );


    constructor(
        address _router,
        address _factory
    ) {
        router = _router;
        factory = _factory;
    }

    /*
     * Function to withdraw stuck tokens
     */
    function withdrawTokens(address[] calldata tokens) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 qty;

            if (tokens[i] == address(0)) {
                qty = address(this).balance;
                (bool success, ) = (owner()).call{value: qty}(new bytes(0));
                require(success, "BNB transfer fail");
            } else {
                qty = IERC20(tokens[i]).balanceOf(address(this));
                IERC20(tokens[i]).safeTransfer(owner(), qty);
            }
        }
    }

    function whitelistedRoutersLength() external view returns (uint256) {
        return whitelistedRouters.length;
    }

    function toggleWhiteListed(address routerAddress) external onlyOwner {
        
        WhiteListedRouterData memory data = whiteListedRoutersData[routerAddress];
        if(data.isWhiteListed){
            
            //Already whitelisted so move this router out of whitelist
           
            //If whiteListed routers are more than 1 swap last router with this router
            if(whitelistedRouters.length > 1){
                
                //calculate total whiteListed routers
                uint length = whitelistedRouters.length;

                //get last whitelisted router address
                address lastRouter = whitelistedRouters[length-1];

                //swap last router with this router
                whitelistedRouters[data.index]  = whitelistedRouters[length-1];

                //overwrite lastRouter address array index
                whiteListedRoutersData[lastRouter].index = data.index;
            }

            //delete given router's whitelisted information
            delete whiteListedRoutersData[routerAddress];

            //decrease whiteListedRouters array length by 1
            whitelistedRouters.pop();

        }
        else{

            //Not whitelisted so whiteList it

            whiteListedRoutersData[routerAddress].index = whitelistedRouters.length;
            whiteListedRoutersData[routerAddress].isWhiteListed = true;
            whitelistedRouters.push(routerAddress);

        }
       
    }



    function checkWhiteListedRouter(address _routerAddress)
        public
        view
        returns (bool)
    {
        return whiteListedRoutersData[_routerAddress].isWhiteListed;
    }

    function minAmountsCalculator(address pair, uint256 liquidity)
        public
        view
        returns (uint256 amount0, uint256 amount1, uint256 amount0WithSlippage, uint256 amount1WithSlippage)
    {
        address token0 = IPancakePair(pair).token0();
        address token1 = IPancakePair(pair).token1();
        uint256 balance0 = IERC20(token0).balanceOf(pair);
        uint256 balance1 = IERC20(token1).balanceOf(pair);
        uint256 totalSupply = IPancakePair(pair).totalSupply();
        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;
        amount0WithSlippage = amount0 - (amount0 / 100);
        amount1WithSlippage = amount1 - (amount1 / 100);
        return (amount0,amount1,amount0WithSlippage, amount1WithSlippage);
    }

    struct LiquidityTransferData {
        bool success;
        uint token0Decimals;
        uint token1Decimals;
        uint token0Remove;
        uint token1Remove;
        uint liquidity;
        uint slippageToken0;
        uint slippageToken1;
    }

    function checkEligible(
        address pairAddress, //otherPairAddress
        address routerAddress //otherRouterAddress
    ) public view returns(bool success){
        if(checkWhiteListedRouter(routerAddress)){
            address token0 = IPancakePair(pairAddress).token0();
            address token1 = IPancakePair(pairAddress).token1();

            //given pairaddress should not present on already set router
            address pair = IPancakeFactory(factory).getPair(token0, token1);

            if(pair != pairAddress){

                //given pairaddress should exist on given router
                address givenPairFactory = IPancakePair(pairAddress).factory();
                address calculatedPair = IPancakeFactory(givenPairFactory).getPair(token0, token1);

                if(calculatedPair == pairAddress){
                    success = true;
                }

            }
        }
    }

    function liquidityConvertData(
        address pairAddress, //otherPairAddress
        address routerAddress, //otherRouterAddress
        uint256 liquidity //amountOfOtheLP to convert
    ) external view returns(LiquidityTransferData memory data){

        if(checkEligible(pairAddress,routerAddress) && liquidity > 0){

            //Calculate amountA and amountB after removing liquidity
            (uint amountA,uint amountB,,) = minAmountsCalculator(
                pairAddress,
                liquidity
            );

            data.success = true;
            data.token0Remove = amountA;
            data.token1Remove = amountB;

            //find token0 and token1
            address token0 = IPancakePair(pairAddress).token0();
            address token1 = IPancakePair(pairAddress).token1();

            address _pairAddress = IPancakeFactory(factory).getPair(
            token0,
            token1
            );

            uint256 _amountA = amountA;
            uint256 _amountB = amountB;

            //Get token0 and token1 reserves for given pair
            uint256 reserveA = 0;
            uint256 reserveB = 0;
            
            
            if(_pairAddress != address(0))
            (reserveA, reserveB, ) = IPancakePair(_pairAddress).getReserves();
            
            if(reserveA > 0 && reserveB > 0){

                address token0New = IPancakePair(_pairAddress).token0();

                if(token0 == token0New && _amountA < _amountB){
                    
                    //calculate amount B to add if amountA is given
                    _amountA = amountA;
                    _amountB = IPancakeRouter01(router).quote(
                    amountA,
                    reserveA,
                    reserveB
                    );

                    if(_amountB > amountB){

                        _amountB = amountB;
                        _amountA = IPancakeRouter01(router).quote(
                        amountB,
                        reserveB,
                        reserveA
                        );

                    }

                }
                else{
                    //calculate amount A to add if amountB is given
                    _amountB = amountB;
                    _amountA = IPancakeRouter01(router).quote(
                    amountB,
                    reserveB,
                    reserveA
                    );

                    if(_amountA > amountA){

                        _amountA = amountA;
                        _amountB = IPancakeRouter01(router).quote(
                        amountA,
                        reserveA,
                        reserveB
                        );

                    }

                }
                
            }

            data.slippageToken0 = amountA - _amountA;
            data.slippageToken1 = amountB - _amountB;

            if(_pairAddress == address(0) || (IPancakePair(_pairAddress).totalSupply()) == 0){
                data.liquidity = Math.sqrt(_amountA * _amountB) - (MINIMUM_LIQUIDITY);
                data.token0Decimals = IPancakePair(token0).decimals();
                data.token1Decimals = IPancakePair(token1).decimals();
            }
            else{
                uint totalSupply = IPancakePair(_pairAddress).totalSupply();
                data.liquidity = Math.min(
                    ((_amountA * totalSupply) / reserveA),
                    ((_amountB * totalSupply) / reserveB));
                data.token0Decimals = IPancakePair(token0).decimals();
                data.token1Decimals = IPancakePair(token1).decimals();
            }
        }

    }

    
    function liquidityConvert(
        address pairAddress, //otherPairAddress
        address routerAddress, //otherRouterAddress
        uint256 liquidity, //amountOfOtheLP to convert
        uint256 deadline
    ) external returns (bool success) {

        require(liquidity > 0,"liquidity amount should be greater than zero");
        
        //check routerAddress is whitelisted or not
        require(checkWhiteListedRouter(routerAddress),"Given Router Address is not whiteListed");

        //find token0 and token1
        address token0 = IPancakePair(pairAddress).token0();
        address token1 = IPancakePair(pairAddress).token1();

        //given pairaddress should not present on already set router
        address pair = IPancakeFactory(factory).getPair(token0, token1);
        require(pair != pairAddress,"Set Router Pair Address is given");

        //given pairaddress should exist on given router
        address givenPairFactory = IPancakePair(pairAddress).factory();
        address calculatedPair = IPancakeFactory(givenPairFactory).getPair(token0, token1);
        require(calculatedPair == pairAddress,"Given Pair not exist on given router");


        //Transfer given liquidity amount from user wallet
        IERC20(pairAddress).safeTransferFrom(
            _msgSender(),
            address(this),
            liquidity
        );

        return liquidityConvertInternal(token0,token1,pairAddress,routerAddress,liquidity,deadline);
        
    }

    uint removeAmountA;
    uint removeAmountB;

    function liquidityConvertInternal(
        address token0,
        address token1,
        address pairAddress, //otherPairAddress
        address routerAddress, //otherRouterAddress
        uint256 liquidity, //amountOfOtheLP to convert
        uint256 deadline
    ) internal returns (bool success) {

        //Calculate Min Amounts of token0 and token1 received
        (,,uint256 amount0Min, uint256 amount1Min) = minAmountsCalculator(
            pairAddress,
            liquidity
        );

        //Give Approval to other router
        IPancakePair(pairAddress).approve(routerAddress, liquidity);

        //Remove Liquidity
        (uint256 amountA, uint256 amountB) = _safeRemoveLiquidity(
            token0,
            token1,
            routerAddress,
            liquidity,
            amount0Min,
            amount1Min,
            address(this),
            deadline
        );

        removeAmountA = amountA;
        removeAmountB = amountB;

        //Slippage = 1 percent
        IERC20(token0).approve(router, amountA);
        IERC20(token1).approve(router, amountB);

        address _setRouterPairAddress = IPancakeFactory(factory).getPair(
            token0,
            token1
        );

        uint256 _amountA = amountA;
        uint256 _amountB = amountB;

        uint _deadline = deadline;

        address _token0 = token0;
        address _token1 = token1;

        address _pairAddress = pairAddress;
        address _routerAddress = routerAddress;
        uint256 _liquidity = liquidity;

        uint finalAmountA;
        uint finalAmountB;

        {

           //Get token0 and token1 reserves for given pair
            uint256 reserveA = 0;
            uint256 reserveB = 0;
            
            
            if(_setRouterPairAddress != address(0))
            (reserveA, reserveB, ) = IPancakePair(_setRouterPairAddress).getReserves();
            
            if(reserveA > 0 && reserveB > 0){

                address token0New = IPancakePair(_setRouterPairAddress).token0();

                if(_token0 == token0New && _amountA < _amountB){
                    
                    //calculate amount B to add if amountA is given
                    _amountA = amountA;
                    _amountB = IPancakeRouter01(router).quote(
                    _amountA,
                    reserveA,
                    reserveB
                    );

                    if(_amountB > amountB){

                        _amountB = amountB;
                        _amountA = IPancakeRouter01(router).quote(
                        _amountB,
                        reserveB,
                        reserveA
                        );

                    }

                }
                else{
                    //calculate amount A to add if amountB is given
                    _amountB = amountB;
                    _amountA = IPancakeRouter01(router).quote(
                    _amountB,
                    reserveB,
                    reserveA
                    );

                    if(_amountA > amountA){

                        _amountA = amountA;
                        _amountB = IPancakeRouter01(router).quote(
                        _amountA,
                        reserveA,
                        reserveB
                        );

                    }

                }
                
            }

            uint amountA_ = _amountA;
            uint amountB_ = _amountB;
            uint deadline_ = _deadline;
            uint256 finalLiquidity;

            (finalAmountA , finalAmountB , finalLiquidity) = _safeAddLiquidity(
                _token0,
                _token1,
                amountA_,
                amountB_,
                slippageCalculator(amountA_),
                slippageCalculator(amountB_),
                _msgSender(),
                deadline_
            );

            emit LiquidityTransferred(
                _pairAddress,
                _routerAddress,
                _liquidity,
                finalLiquidity,
                _msgSender()
            );
            

        }


        if((removeAmountA - finalAmountA) > 0){
            
            uint token0Bal = IERC20(_token0).balanceOf(address(this));
            
            if(token0Bal > (removeAmountA - _amountA))
            IERC20(_token0).safeTransfer(_msgSender(), (removeAmountA - finalAmountA));
            else
            IERC20(_token0).safeTransfer(_msgSender(), token0Bal);

        }

        if((removeAmountB - finalAmountB) > 0){

            uint token1Bal = IERC20(_token1).balanceOf(address(this));
            
            if(token1Bal > (removeAmountB - finalAmountB))
            IERC20(_token1).safeTransfer(_msgSender(), (removeAmountB - finalAmountB));
            else
            IERC20(_token1).safeTransfer(_msgSender(), token1Bal);
        }

        removeAmountA = 0;
        removeAmountB = 0;

        return true;

    }

    /*
     * Safe Remove Liquidity
     */
    function _safeRemoveLiquidity(
        address tokenA,
        address tokenB,
        address _routerAddress,
        uint256 liquidity,
        uint256 amountAmin,
        uint256 amountBmin,
        address _to,
        uint256 _deadline
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        (amountA, amountB) = IPancakeRouter01(_routerAddress).removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAmin,
            amountBmin,
            _to,
            _deadline
        );
    }

    function _safeAddLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAmin,
        uint256 amountBmin,
        address _to,
        uint256 _deadline
    )
        internal
        virtual
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB, liquidity) = IPancakeRouter01(router)
            .addLiquidity(
                tokenA,
                tokenB,
                amountADesired,
                amountBDesired,
                amountAmin,
                amountBmin,
                _to,
                _deadline
            );
    }

    function slippageCalculator(uint256 amount)
        internal
        pure
        returns (uint256)
    {
        uint256 amountWithSlippage = amount - (amount / 100);
        return amountWithSlippage;
    }
}

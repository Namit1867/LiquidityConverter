const { expect, assert } = require('chai')
const { waffle } = require('hardhat')
const { ethers } = require('ethers')
const { formatEther } = require('ethers/lib/utils')

const dotenv = require('dotenv')
dotenv.config()

//PANCAKE-DATA

const pancakeRouterAddress = '0x10ED43C718714eb63d5aA57B78B54704E256024E'
const pancakeFactoryAddress = '0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73'
const pancakePairAddress1 = '0x804678fa97d91B974ec2af3c843270886528a9E6' //CAKE-BUSD
const pancakePairAddress2 = '0x0eD7e52944161450477ee417DE9Cd3a859b14fD0' //CAKE-WBNB
const pancakePairAddress3 = '0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16' //BUSD-WBNB
const pancakePairAddress4 = '0x28415ff2C35b65B9E5c7de82126b4015ab9d031F' //ADA-WBNB

//APESWAP-DATA

const apeFactoryAddress = '0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6'
const apeRouterAddress = '0xcF0feBd3f17CEf5b47b0cD257aCf6025c5BFf3b7'

const GiveTime = () => {
  const time = Math.round(new Date().getTime() / 1000) //convert to seconds
  const Add = 20 * 600000 //Add minutes
  const FinalTime = time + Add
  return FinalTime
}

const tokens = (n) => {
  const x = ethers.utils.parseEther(n.toString())
  return x
}

// describe('RESET MAINNET FORK', function () {
//   it('Should reset BSC Mainnet fork', async function () {
//     await network.provider.request({
//       method: 'hardhat_reset',
//       params: [
//         {
//           forking: {
//             jsonRpcUrl: process.env.BSC_MAIN_NET_API_URL,
//           },
//         },
//       ],
//     })
//   })
// })

describe('Deploy and Test LiquidityConverter contracts', () => {
  let deployer
  it(`should deploy`, async () => {
    ;[deployer] = await hre.ethers.getSigners()

    liquidityTransfer = await hre.ethers.getContractFactory(
      'LiquidityConverter',
    )
    liquidityTransferInstance = await liquidityTransfer.deploy(
      apeRouterAddress,
      apeFactoryAddress,
    )
    liquidityTransferAddress = liquidityTransferInstance.address
  })

  it(`should toggle pancakeRouter ${pancakeRouterAddress} whiteListed status`, async () => {
    await liquidityTransferInstance.toggleWhiteListed(pancakeRouterAddress)
    expect(
      await liquidityTransferInstance.checkWhiteListedRouter(
        pancakeRouterAddress,
      ),
    ).to.be.true
    expect(await liquidityTransferInstance.whitelistedRouters(0)).to.equal(
      pancakeRouterAddress,
    )
  })

  it('should remove pancakePairAddress1 liqudity and add in apeSwap', async () => {
    
    const pairImpersonater = '0x4facd9abd8d9d5c45ed4d1e76320cfff27141e11'
    const pairAddress = pancakePairAddress1;
    const pairInstance = await hre.ethers.getContractAt(
      'PancakePair',
      pairAddress,
    )

    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [pairImpersonater],
    })

    const signer = await hre.ethers.getSigner(pairImpersonater)

    const bal = await pairInstance.balanceOf(signer.address)
    await pairInstance.connect(signer).transfer(deployer.address, bal)

    const liquidity = await pairInstance.balanceOf(deployer.address)
    await pairInstance.approve(liquidityTransferAddress, liquidity)

    const res = (
      await liquidityTransferInstance.liquidityConvertData(
        pairAddress,
        pancakeRouterAddress,
        liquidity,
      )
    );

    
    //decimals

    const token0 = await pairInstance.token0();
    const token1 = await pairInstance.token1();
    
    const token0Instance = await hre.ethers.getContractAt(
      'Token',
      token0,
    )
    const token1Instance = await hre.ethers.getContractAt(
      'Token',
      token1,
    )

    const decimal0 = await token0Instance.decimals();
    const decimal1 = await token1Instance.decimals();

    //remove liquidity
    const totalSupply = await pairInstance.totalSupply();
    const token0Balance = await token0Instance.balanceOf(pairAddress)
    const token1Balance = await token1Instance.balanceOf(pairAddress)

    const token0Remove = liquidity.mul(token0Balance).div(totalSupply);
    const token1Remove = liquidity.mul(token1Balance).div(totalSupply);

    await liquidityTransferInstance.liquidityConvert(
      pairAddress,
      pancakeRouterAddress,
      liquidity,
      GiveTime(),
    )


    expect(res.success).to.equal(true);
    expect(res.token0Decimals).to.equal(decimal0);
    expect(res.token1Decimals).to.equal(decimal1);
    expect(res.token0Remove).to.equal(token0Remove);
    expect(res.token1Remove).to.equal(token1Remove);


    await hre.network.provider.request({
      method: 'hardhat_stopImpersonatingAccount',
      params: [pairImpersonater],
    })
  })

  it('should remove pancakePairAddress2 liqudity and add in apeSwap', async () => {
    
    const pairImpersonater = '0x14B2e8329b8e06BCD524eb114E23fAbD21910109'
    const pairAddress = pancakePairAddress2;
    const pairInstance = await hre.ethers.getContractAt(
      'PancakePair',
      pairAddress,
    )

    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [pairImpersonater],
    })

    const signer = await hre.ethers.getSigner(pairImpersonater)

    const bal = await pairInstance.balanceOf(signer.address)
    await pairInstance.connect(signer).transfer(deployer.address, bal)

    const liquidity = await pairInstance.balanceOf(deployer.address)
    await pairInstance.approve(liquidityTransferAddress, liquidity)

    const res = (
      await liquidityTransferInstance.liquidityConvertData(
        pairAddress,
        pancakeRouterAddress,
        liquidity,
      )
    );

    
    //decimals

    const token0 = await pairInstance.token0();
    const token1 = await pairInstance.token1();
    
    const token0Instance = await hre.ethers.getContractAt(
      'Token',
      token0,
    )
    const token1Instance = await hre.ethers.getContractAt(
      'Token',
      token1,
    )

    const decimal0 = await token0Instance.decimals();
    const decimal1 = await token1Instance.decimals();

    //remove liquidity
    const totalSupply = await pairInstance.totalSupply();
    const token0Balance = await token0Instance.balanceOf(pairAddress)
    const token1Balance = await token1Instance.balanceOf(pairAddress)

    const token0Remove = liquidity.mul(token0Balance).div(totalSupply);
    const token1Remove = liquidity.mul(token1Balance).div(totalSupply);

    await liquidityTransferInstance.liquidityConvert(
      pairAddress,
      pancakeRouterAddress,
      liquidity,
      GiveTime(),
    )


    expect(res.success).to.equal(true);
    expect(res.token0Decimals).to.equal(decimal0);
    expect(res.token1Decimals).to.equal(decimal1);
    expect(res.token0Remove).to.equal(token0Remove);
    expect(res.token1Remove).to.equal(token1Remove);


    await hre.network.provider.request({
      method: 'hardhat_stopImpersonatingAccount',
      params: [pairImpersonater],
    })
  })

  it('should remove pancakePairAddress3 liqudity and add in apeSwap', async () => {
    
    const pairImpersonater = '0x14B2e8329b8e06BCD524eb114E23fAbD21910109'
    const pairAddress = pancakePairAddress3;
    const pairInstance = await hre.ethers.getContractAt(
      'PancakePair',
      pairAddress,
    )

    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [pairImpersonater],
    })

    const signer = await hre.ethers.getSigner(pairImpersonater)

    const bal = await pairInstance.balanceOf(signer.address)
    await pairInstance.connect(signer).transfer(deployer.address, bal)

    const liquidity = await pairInstance.balanceOf(deployer.address)
    await pairInstance.approve(liquidityTransferAddress, liquidity)

    const res = (
      await liquidityTransferInstance.liquidityConvertData(
        pairAddress,
        pancakeRouterAddress,
        liquidity,
      )
    );

    
    //decimals

    const token0 = await pairInstance.token0();
    const token1 = await pairInstance.token1();
    
    const token0Instance = await hre.ethers.getContractAt(
      'Token',
      token0,
    )
    const token1Instance = await hre.ethers.getContractAt(
      'Token',
      token1,
    )

    const decimal0 = await token0Instance.decimals();
    const decimal1 = await token1Instance.decimals();

    //remove liquidity
    const totalSupply = await pairInstance.totalSupply();
    const token0Balance = await token0Instance.balanceOf(pairAddress)
    const token1Balance = await token1Instance.balanceOf(pairAddress)

    const token0Remove = liquidity.mul(token0Balance).div(totalSupply);
    const token1Remove = liquidity.mul(token1Balance).div(totalSupply);

    await liquidityTransferInstance.liquidityConvert(
      pairAddress,
      pancakeRouterAddress,
      liquidity,
      GiveTime(),
    )


    expect(res.success).to.equal(true);
    expect(res.token0Decimals).to.equal(decimal0);
    expect(res.token1Decimals).to.equal(decimal1);
    expect(res.token0Remove).to.equal(token0Remove);
    expect(res.token1Remove).to.equal(token1Remove);


    await hre.network.provider.request({
      method: 'hardhat_stopImpersonatingAccount',
      params: [pairImpersonater],
    })
  })

  it('should remove pancakePairAddress4 liqudity and add in apeSwap', async () => {
    
    const pairImpersonater = '0x87c1D4e5BaB13e483654B0748880fdc945007D40'
    const pairAddress = pancakePairAddress4;
    const pairInstance = await hre.ethers.getContractAt(
      'PancakePair',
      pairAddress,
    )

    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [pairImpersonater],
    })

    const signer = await hre.ethers.getSigner(pairImpersonater)

    const bal = await pairInstance.balanceOf(signer.address)
    await pairInstance.connect(signer).transfer(deployer.address, bal)

    const liquidity = await pairInstance.balanceOf(deployer.address)
    await pairInstance.approve(liquidityTransferAddress, liquidity)

    const res = (
      await liquidityTransferInstance.liquidityConvertData(
        pairAddress,
        pancakeRouterAddress,
        liquidity,
      )
    );

    
    //decimals

    const token0 = await pairInstance.token0();
    const token1 = await pairInstance.token1();
    
    const token0Instance = await hre.ethers.getContractAt(
      'Token',
      token0,
    )
    const token1Instance = await hre.ethers.getContractAt(
      'Token',
      token1,
    )

    const decimal0 = await token0Instance.decimals();
    const decimal1 = await token1Instance.decimals();

    //remove liquidity
    const totalSupply = await pairInstance.totalSupply();
    const token0Balance = await token0Instance.balanceOf(pairAddress)
    const token1Balance = await token1Instance.balanceOf(pairAddress)

    const token0Remove = liquidity.mul(token0Balance).div(totalSupply);
    const token1Remove = liquidity.mul(token1Balance).div(totalSupply);

    await liquidityTransferInstance.liquidityConvert(
      pairAddress,
      pancakeRouterAddress,
      liquidity,
      GiveTime(),
    )


    expect(res.success).to.equal(true);
    expect(res.token0Decimals).to.equal(decimal0);
    expect(res.token1Decimals).to.equal(decimal1);
    expect(res.token0Remove).to.equal(token0Remove);
    expect(res.token1Remove).to.equal(token1Remove);


    await hre.network.provider.request({
      method: 'hardhat_stopImpersonatingAccount',
      params: [pairImpersonater],
    })
  })
})

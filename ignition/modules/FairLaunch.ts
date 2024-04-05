import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const 
  price = "770000000000000",  // 0.00077 ETH
  amountPerUnits = 2,
  totalSupply = "10000000000000000000000000",
  launcher = "0x1429140EFBD4d5355706B63636F69127c2657658",
  uniswapRouter = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
  uniswapFactory = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f", // ETH kovan, goerli, etc.
  name="UltraCoin",
  symbol="ULTRA";

export default buildModule("FairLaunchToken", (m) => {
  const token = m.contract("FairLaunchToken", [
    price,
    amountPerUnits,
    totalSupply,
    launcher,
    uniswapRouter,
    uniswapFactory,
    name,
    symbol
  ]);

  return { token };
});
// 部署脚本：仅用于本地/测试网原型
// 用法：npx hardhat node  然后在另一个终端  npx hardhat run scripts/deploy.js --network localhost
const hre = require("hardhat");

async function main() {
  const [deployer, user] = await hre.ethers.getSigners();
  const USDC_UNIT = 10n ** 6n;

  console.log("Deployer:", deployer.address);

  // 1. Mock USDC（测试网用；主网替换为真实 USDC）
  const MockUSDC = await hre.ethers.getContractFactory("MockUSDC");
  const usdc = await MockUSDC.deploy();
  await usdc.waitForDeployment();

  // 2. 稳定币 LUSD（1:1 USDC）
  const StableToken = await hre.ethers.getContractFactory("StableToken");
  const lusd = await StableToken.deploy(await usdc.getAddress(), deployer.address);
  await lusd.waitForDeployment();

  // 3. 赠券 LVCH（不可转让）
  const VoucherToken = await hre.ethers.getContractFactory("VoucherToken");
  const voucher = await VoucherToken.deploy(deployer.address);
  await voucher.waitForDeployment();

  // 4. 彩票合约（票价 1 USDC/张）
  const SimpleLottery = await hre.ethers.getContractFactory("SimpleLottery");
  const lottery = await SimpleLottery.deploy(
    await lusd.getAddress(),
    await voucher.getAddress(),
    1n * USDC_UNIT,
    deployer.address
  );
  await lottery.waitForDeployment();

  // 授权：彩票合约可以销毁赠券
  await (await voucher.grantRole(await voucher.MINTER_ROLE(), await lottery.getAddress())).wait();

  console.log("MockUSDC:     ", await usdc.getAddress());
  console.log("StableToken:  ", await lusd.getAddress());
  console.log("VoucherToken: ", await voucher.getAddress());
  console.log("SimpleLottery:", await lottery.getAddress());

  // 给演示用户一些 USDC 便于测试
  if (user) {
    await (await usdc.mint(user.address, 1000n * USDC_UNIT)).wait();
    console.log("Minted 1000 USDC to demo user:", user.address);
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});

const { expect } = require("chai");
const { ethers } = require("hardhat");

const UNIT = 10n ** 6n; // 6 位小数
const usdc = (n) => BigInt(n) * UNIT;

describe("彩票平台 稳定币 + 赠券 原型", function () {
  let deployer, user, other;
  let usdcToken, lusd, voucher, lottery;

  beforeEach(async function () {
    [deployer, user, other] = await ethers.getSigners();

    const MockUSDC = await ethers.getContractFactory("MockUSDC");
    usdcToken = await MockUSDC.deploy();
    await usdcToken.waitForDeployment();

    const StableToken = await ethers.getContractFactory("StableToken");
    lusd = await StableToken.deploy(await usdcToken.getAddress(), deployer.address);
    await lusd.waitForDeployment();

    const VoucherToken = await ethers.getContractFactory("VoucherToken");
    voucher = await VoucherToken.deploy(deployer.address);
    await voucher.waitForDeployment();

    const SimpleLottery = await ethers.getContractFactory("SimpleLottery");
    lottery = await SimpleLottery.deploy(
      await lusd.getAddress(),
      await voucher.getAddress(),
      usdc(1), // 1 USDC / 张
      deployer.address
    );
    await lottery.waitForDeployment();

    // 彩票合约获得销毁赠券的权限
    await voucher.grantRole(await voucher.MINTER_ROLE(), await lottery.getAddress());

    // 给用户 1000 USDC
    await usdcToken.mint(user.address, usdc(1000));
  });

  it("充值 1:1 铸造 LUSD", async function () {
    await usdcToken.connect(user).approve(await lusd.getAddress(), usdc(1000));
    await lusd.connect(user).deposit(usdc(1000));
    expect(await lusd.balanceOf(user.address)).to.equal(usdc(1000));
    expect(await usdcToken.balanceOf(await lusd.getAddress())).to.equal(usdc(1000));
  });

  it("销毁 LUSD 1:1 赎回 USDC", async function () {
    await usdcToken.connect(user).approve(await lusd.getAddress(), usdc(500));
    await lusd.connect(user).deposit(usdc(500));

    await lusd.connect(user).redeem(usdc(200));
    expect(await lusd.balanceOf(user.address)).to.equal(usdc(300));
    expect(await usdcToken.balanceOf(user.address)).to.equal(usdc(700));
  });

  it("赠券不可转让", async function () {
    await voucher.mint(user.address, usdc(20));
    await expect(
      voucher.connect(user).transfer(other.address, usdc(1))
    ).to.be.revertedWith("voucher non-transferable");
  });

  it("买票优先扣赠券，不足再用 LUSD", async function () {
    // 用户充值 1000 -> 1000 LUSD
    await usdcToken.connect(user).approve(await lusd.getAddress(), usdc(1000));
    await lusd.connect(user).deposit(usdc(1000));

    // 平台按 2% 发赠券 20
    await voucher.mint(user.address, usdc(20));

    // 买 5 张，票价 1 -> 成本 5，赠券足够，全部用赠券
    await lottery.connect(user).buyTicket(5);
    expect(await voucher.balanceOf(user.address)).to.equal(usdc(15));
    expect(await lusd.balanceOf(user.address)).to.equal(usdc(1000)); // LUSD 未动
    expect(await lottery.tickets(user.address)).to.equal(5);

    // 再买 20 张，成本 20，赠券只剩 15 -> 用 15 赠券 + 5 LUSD
    await lusd.connect(user).approve(await lottery.getAddress(), usdc(5));
    await lottery.connect(user).buyTicket(20);
    expect(await voucher.balanceOf(user.address)).to.equal(0n);
    expect(await lusd.balanceOf(user.address)).to.equal(usdc(995));
    expect(await lottery.tickets(user.address)).to.equal(25);
  });

  it("冻结后不能转出、不能赎回；解冻后恢复", async function () {
    await usdcToken.connect(user).approve(await lusd.getAddress(), usdc(100));
    await lusd.connect(user).deposit(usdc(100));

    await lusd.freeze(user.address);

    // 转出被拒
    await expect(
      lusd.connect(user).transfer(other.address, usdc(1))
    ).to.be.revertedWith("from frozen");

    // 赎回被拒
    await expect(lusd.connect(user).redeem(usdc(10))).to.be.revertedWith(
      "account frozen"
    );

    // 解冻后恢复
    await lusd.unfreeze(user.address);
    await lusd.connect(user).transfer(other.address, usdc(1));
    expect(await lusd.balanceOf(other.address)).to.equal(usdc(1));
  });

  it("冻结仍可收款（便于退款/派奖）", async function () {
    await usdcToken.connect(user).approve(await lusd.getAddress(), usdc(100));
    await lusd.connect(user).deposit(usdc(100));

    await lusd.freeze(user.address);
    // 别人转给他，应成功
    await usdcToken.mint(other.address, usdc(10));
    await usdcToken.connect(other).approve(await lusd.getAddress(), usdc(10));
    await lusd.connect(other).deposit(usdc(10));
    await lusd.connect(other).transfer(user.address, usdc(10));
    expect(await lusd.balanceOf(user.address)).to.equal(usdc(110));
  });

  it("只有 BLACKLISTER 能冻结", async function () {
    await expect(lusd.connect(user).freeze(other.address)).to.be.reverted;
  });
});

# 彩票平台 · 稳定币 + 赠券（测试网原型）

> ⚠️ **仅用于测试网 / 本地演示。** 主网使用前必须完成：智能合约审计、法律与牌照确认（博彩、AML/KYC、货币传输）、储备与审计体系。切勿直接部署主网。

## 这是什么

按"稳定币负责钱、赠券负责拉新"的双轨设计实现的原型：

- **LUSD（StableToken）**：1:1 锚定 USDC。存 1 USDC 铸 1 LUSD，销毁 1 LUSD 赎回 1 USDC。支持合规冻结（黑名单）。
- **LVCH（VoucherToken）**：赠券。按充值额 2% 发放，**不可转让**，只能用于买彩票（消费即销毁），**不可提现**。
- **SimpleLottery**：买票时**先扣赠券、不足再用 LUSD**。

因为折扣只存在于"只能消费的赠券"里，币本身按 1.00 买入、1:1 赎回，所以**不存在"低买高提"的套利空间**。

## 目录

```
contracts/
  MockUSDC.sol        测试网 USDC（6 位小数）
  StableToken.sol     LUSD：1:1 铸造/赎回 + 冻结
  VoucherToken.sol    LVCH：不可转让赠券
  SimpleLottery.sol   买票：赠券优先
test/
  LotterySystem.test.js
scripts/
  deploy.js
index.html            项目介绍页（落地页，GitHub Pages 首页）
whitepaper/
  index.html          技术白皮书（含目录、打印样式）
assets/               落地页图标资源
dapp/
  index.html          DApp 主界面（单文件、纯前端、无外部依赖）
  manifest.json       PWA 清单，可「添加到主屏幕」以独立窗口运行
  icon-192.png        应用图标
  icon-512.png        应用图标（同时声明 maskable）
  assets/             代币图标
demo/
  index.html          旧地址跳转页（自动前往 /dapp/）
```

## 快速开始

```bash
npm install
npx hardhat compile
npx hardhat test          # 7 个测试
```

本地链部署：

```bash
# 终端 A
npx hardhat node

# 终端 B
npx hardhat run scripts/deploy.js --network localhost
```

## 两个页面

| 路径 | 用途 |
|---|---|
| `/`（根目录 `index.html`） | 项目介绍落地页：概念、运作方式、用例、透明度、风险披露、FAQ |
| `/dapp/` | **DApp 主界面**：K 线、行情、持仓、风险扫描、钱包连接、P2P、链上订单流 |
| `/demo/` | 旧地址，自动跳转至 `/dapp/` |
| `/whitepaper/` | 技术白皮书：双代币模型、储备机制、合约架构、权限矩阵、风险披露、已知限制 |

在线地址：https://mrkk9919.github.io/LUSD/

## DApp

入口：https://mrkk9919.github.io/LUSD/dapp/ ，或从落地页的 **Launch DApp** 按钮进入。

单文件、零依赖，直接双击 `dapp/index.html` 也能打开（`file://` 下 PWA 清单不生效，其余功能正常）。

### 交易前置条件

底部 **Buy / Sell** 打开交易面板后，点「买入 / 卖出 LUSD」会依次校验，任一条不满足都不执行：

| 校验 | 不通过时的行为 |
|---|---|
| 钱包已连接 | 提示「请先连接钱包再交易」并自动弹出钱包选择 |
| 网络为 Base（`0x2105`） | 提示「请先切换到 Base 网络」并自动发起 `wallet_switchEthereumChain` |
| ETH ≥ **0.0005 ETH**（Gas） | 提示「ETH 不足：至少需要 0.0005 ETH 支付 Gas」 |

按钮下方常驻一行 Gas 状态：未连接显示灰点、余额不足显示红点 + 实际余额、充足显示绿点 + 余额。
阈值由 `MIN_GAS_ETH` 常量控制，改一行即可调整。

页面包含：K 线图（含 MA/成交量/多周期）、代币信息、持仓分布、风险扫描、动态流、P2P 买卖
（50 家商家 + 越南银行收款账号绑定 + **链上订单流**），以及一个**支持任意 EIP-1193 钱包的连接器**
（EIP-6963 自动发现 + 传统注入回退 + 只读地址查看）。

P2P 页分「商家挂单 / 链上订单」两个视图。链上订单视图按 `Type/Amount/Time · Value/Price · Addresses`
三列排布，Buy/Sell 用绿/红药丸标注，列表每 5 秒从顶部推入一条新成交并整体老化时间戳，
底部固定 Buy / Sell 按钮与页面其余部分一致。

合约地址（右上 `⋯` → 在 OKX 浏览器查看）、钱包地址（`在 OKX 查看`）以及链上订单里的任意地址，
均跳转 **OKX Web3 浏览器**（`https://web3.okx.com/explorer/base/...`，Base 链）。
换成正式部署地址后，`ADDR` 与订单流地址即可指向真实链上数据。

界面支持**中文 / English / Tiếng Việt** 三语切换（右上角 `中 / EN / VI`），选择写入
`localStorage['lusd_lang']`；首次访问按浏览器语言自动匹配（`vi-*` → 越南语，`en-*` → 英文，其余 → 中文）。

> ⚠️ **页面内的行情数据全部为模拟值**（市值、持币人数、流动性、Top10 占比、交易量等均为占位数字），
> 不代表任何真实链上状态。钱包连接只读取地址与余额，不会发起交易。
> 正式上线前必须接入真实数据源，并把占位数字全部替换。

## 关键规则（与合规要点对应）

| 规则 | 实现 |
|---|---|
| 1 币 = 1 USDC | `deposit` / `redeem` 1:1 |
| 赠券 2%、只能消费 | `VoucherToken` 覆盖 `_update`，禁止转账 |
| 冻结只限转出/提现，仍可收款 | `StableToken._update` 仅拦 `from` |
| 冻结需权限 | `BLACKLISTER_ROLE` |
| 可暂停 | `PAUSER_ROLE` + `Pausable` |

## 未实现 / 生产前必须补

- 真实 USDC 地址替换 `MockUSDC`；储备地址与 Proof of Reserves。
- 赎回手续费、限额、KYC/AML 接口、制裁名单筛查。
- 多签 + timelock 管理权限；合约审计。
- 后端：充值监听、对账、冻结审批流、客服工单。
- 合规：博彩牌照、货币传输/电子货币牌照、用户协议中的冻结条款。

## 免责声明

本项目为技术原型，不构成法律或投资建议。彩票 + 跨境 + 代币属强监管领域，上线前请务必咨询目标市场持牌律师。

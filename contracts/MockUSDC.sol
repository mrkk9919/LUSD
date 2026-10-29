// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockUSDC
/// @notice 仅用于测试网的 USDC 模拟币（6 位小数，与真实 USDC 一致）。
///         主网请替换为真实 USDC 地址，切勿部署此合约到主网。
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice 测试用：任意铸造
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

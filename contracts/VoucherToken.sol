// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title VoucherToken (LVCH)
/// @notice 平台赠券：按充值额 2% 赠送，只能用于购买彩票，不可转让、不可提现。
///         通过覆盖 _update，只允许"铸造(from=0)"和"销毁(to=0)"，禁止任何地址间转账。
contract VoucherToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    event VoucherMinted(address indexed to, uint256 amount);
    event VoucherBurned(address indexed from, uint256 amount);

    constructor(address admin) ERC20("Lottery Voucher", "LVCH") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice 平台发放赠券
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
        emit VoucherMinted(to, amount);
    }

    /// @notice 使用赠券时销毁（由彩票合约调用）
    function burnFrom(address from, uint256 amount) external onlyRole(MINTER_ROLE) {
        _burn(from, amount);
        emit VoucherBurned(from, amount);
    }

    /// @dev 仅允许 mint(from=0) / burn(to=0)，禁止地址间转账 => 不可转让
    function _update(address from, address to, uint256 value) internal override {
        require(from == address(0) || to == address(0), "voucher non-transferable");
        super._update(from, to, value);
    }
}

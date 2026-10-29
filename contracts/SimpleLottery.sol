// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IVoucherBurnable {
    function burnFrom(address from, uint256 amount) external;
}

/// @title SimpleLottery
/// @notice 极简彩票合约原型：买票时"先用赠券、再用 LUSD 补足"。
///         赠券只能在这里被销毁（消费），无法提现或转让。
contract SimpleLottery is Ownable {
    IERC20 public immutable lusd;
    IVoucherBurnable public immutable voucher;

    /// @notice 单张票价（以 LUSD 计，6 位小数）
    uint256 public ticketPrice;

    mapping(address => uint256) public tickets;

    event TicketPurchased(
        address indexed user,
        uint256 count,
        uint256 voucherUsed,
        uint256 lusdUsed
    );
    event TicketPriceUpdated(uint256 oldPrice, uint256 newPrice);

    constructor(
        address _lusd,
        address _voucher,
        uint256 _ticketPrice,
        address initialOwner
    ) Ownable(initialOwner) {
        require(_lusd != address(0) && _voucher != address(0), "zero addr");
        require(_ticketPrice > 0, "price zero");
        lusd = IERC20(_lusd);
        voucher = IVoucherBurnable(_voucher);
        ticketPrice = _ticketPrice;
    }

    function setTicketPrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "price zero");
        emit TicketPriceUpdated(ticketPrice, newPrice);
        ticketPrice = newPrice;
    }

    /// @notice 购买 count 张彩票。优先扣赠券，不足部分从 LUSD 扣。
    ///         调用前需对 LUSD 向本合约 approve（若需用到 LUSD）。
    function buyTicket(uint256 count) external {
        require(count > 0, "count zero");
        uint256 cost = count * ticketPrice;

        uint256 voucherBal = IERC20(address(voucher)).balanceOf(msg.sender);
        uint256 voucherUsed = voucherBal < cost ? voucherBal : cost;

        if (voucherUsed > 0) {
            voucher.burnFrom(msg.sender, voucherUsed);
        }

        uint256 lusdUsed = cost - voucherUsed;
        if (lusdUsed > 0) {
            require(
                lusd.transferFrom(msg.sender, address(this), lusdUsed),
                "lusd transfer failed"
            );
        }

        tickets[msg.sender] += count;
        emit TicketPurchased(msg.sender, count, voucherUsed, lusdUsed);
    }
}

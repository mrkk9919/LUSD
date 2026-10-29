// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title StableToken (LUSD)
/// @notice 1:1 锚定 USDC 的平台稳定币原型。
///         - 存入 1 USDC 铸造 1 LUSD
///         - 销毁 1 LUSD 赎回 1 USDC
///         - 支持合规冻结（黑名单）：被冻结地址不能转出、不能赎回
///         仅测试网原型，主网使用前必须审计 + 法律合规确认。
contract StableToken is ERC20, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IERC20 public immutable usdc;

    /// @notice 被冻结（黑名单）的地址
    mapping(address => bool) public frozen;

    event Deposited(address indexed user, uint256 usdcAmount, uint256 tokenAmount);
    event Redeemed(address indexed user, uint256 tokenAmount, uint256 usdcAmount);
    event Frozen(address indexed user, address indexed by);
    event Unfrozen(address indexed user, address indexed by);

    constructor(address _usdc, address admin) ERC20("Lottery USD", "LUSD") {
        require(_usdc != address(0), "usdc zero");
        usdc = IERC20(_usdc);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BLACKLISTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice 存入 USDC，1:1 铸造 LUSD。调用前需先 approve 本合约。
    function deposit(uint256 usdcAmount) external whenNotPaused {
        require(!frozen[msg.sender], "account frozen");
        require(usdcAmount > 0, "amount zero");
        require(usdc.transferFrom(msg.sender, address(this), usdcAmount), "usdc transfer failed");
        _mint(msg.sender, usdcAmount);
        emit Deposited(msg.sender, usdcAmount, usdcAmount);
    }

    /// @notice 销毁 LUSD，1:1 赎回 USDC。
    function redeem(uint256 amount) external whenNotPaused {
        require(!frozen[msg.sender], "account frozen");
        require(amount > 0, "amount zero");
        _burn(msg.sender, amount);
        require(usdc.transfer(msg.sender, amount), "usdc transfer failed");
        emit Redeemed(msg.sender, amount, amount);
    }

    /// @notice 冻结地址（合规/风控用）
    function freeze(address user) external onlyRole(BLACKLISTER_ROLE) {
        frozen[user] = true;
        emit Frozen(user, msg.sender);
    }

    /// @notice 解冻地址
    function unfreeze(address user) external onlyRole(BLACKLISTER_ROLE) {
        frozen[user] = false;
        emit Unfrozen(user, msg.sender);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @dev 冻结只限制"转出/赎回"，仍允许收款（便于退款/派奖）。
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0)) {
            require(!frozen[from], "from frozen");
        }
        super._update(from, to, value);
    }
}

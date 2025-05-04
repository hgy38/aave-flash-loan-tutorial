// contracts/Dex.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// 导入ERC20代币接口
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

/// @title 去中心化交易所合约
contract Dex {
    address payable public owner; // 合约所有者
    
    // Goerli测试网AAVE代币地址
    address private immutable daiAddress = 0xDF1742fE5b0bFc12331D8EAec6b478DfDbD31464; // DAI地址
    address private immutable usdcAddress = 0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43; // USDC地址

    IERC20 private dai;  // DAI代币实例
    IERC20 private usdc; // USDC代币实例

    // 交易所汇率参数
    uint256 dexARate = 90;  // DAI买入汇率（单位USDC）
    uint256 dexBRate = 100; // DAI卖出汇率（单位USDC）

    // 用户资产余额映射
    mapping(address => uint256) public daiBalances;  // 用户DAI余额
    mapping(address => uint256) public usdcBalances; // 用户USDC余额

    /// @dev 构造函数初始化代币实例
    constructor() {
        owner = payable(msg.sender);
        dai = IERC20(daiAddress);
        usdc = IERC20(usdcAddress);
    }

    /// @dev 存入USDC
    /// @param _amount 存入数量（考虑代币精度）
    function depositUSDC(uint256 _amount) external {
        usdcBalances[msg.sender] += _amount;
        uint256 allowance = usdc.allowance(msg.sender, address(this));
        require(allowance >= _amount, "请先授权足够额度");
        usdc.transferFrom(msg.sender, address(this), _amount);
    }

    /// @dev 存入DAI
    /// @param _amount 存入数量（考虑代币精度）
    function depositDAI(uint256 _amount) external {
        daiBalances[msg.sender] += _amount;
        uint256 allowance = dai.allowance(msg.sender, address(this));
        require(allowance >= _amount, "请先授权足够额度");
        dai.transferFrom(msg.sender, address(this), _amount);
    }

    /// @dev 使用USDC购买DAI
    function buyDAI() external {
        // 计算可获得的DAI数量（考虑USDC的6位小数和DAI的18位小数）
        uint256 daiToReceive = ((usdcBalances[msg.sender] / dexARate) * 100) * (10**12);
        dai.transfer(msg.sender, daiToReceive);
    }

    /// @dev 卖出DAI换取USDC
    function sellDAI() external {
        // 计算可获得的USDC数量（考虑小数位数转换）
        uint256 usdcToReceive = ((daiBalances[msg.sender] * dexBRate) / 100) / (10**12);
        usdc.transfer(msg.sender, usdcToReceive);
    }

    /// @dev 查询合约代币余额
    /// @param _tokenAddress 代币地址
    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    /// @dev 提取合约资金（仅限所有者）
    /// @param _tokenAddress 要提取的代币地址
    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    /// @dev 权限修饰符：仅合约所有者
    modifier onlyOwner() {
        require(msg.sender == owner, "仅合约所有者可操作");
        _;
    }

    /// @dev 接收以太币的回退函数
    receive() external payable {}
}

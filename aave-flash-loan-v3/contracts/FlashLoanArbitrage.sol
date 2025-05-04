// contracts/FlashLoan.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// 导入AAVE V3闪电贷基础合约
import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
// 导入AAVE资金池地址提供者接口
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
// 导入ERC20代币接口
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

/// @title 去中心化交易所接口
interface IDex {
    function depositUSDC(uint256 _amount) external;
    function depositDAI(uint256 _amount) external;
    function buyDAI() external;
    function sellDAI() external;
}

/// @title 闪电贷套利合约
contract FlashLoanArbitrage is FlashLoanSimpleReceiverBase {
    address payable owner; // 合约所有者

    // Goerli测试网代币地址
    address private immutable daiAddress = 0xDF1742fE5b0bFc12331D8EAec6b478DfDbD31464; // DAI地址
    address private immutable usdcAddress = 0xA2025B15a1757311bfD68cb14eaeFCc237AF5b43; // USDC地址
    address private dexContractAddress = 0xD6e8c479B6B62d8Ce985C0f686D39e96af9424df; // 去中心化交易所合约地址

    IERC20 private dai;  // DAI代币实例
    IERC20 private usdc; // USDC代币实例
    IDex private dexContract; // 去中心化交易所实例

    /// @dev 构造函数初始化合约
    /// @param _addressProvider AAVE资金池地址提供者
    constructor(address _addressProvider)
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
        owner = payable(msg.sender);
        dai = IERC20(daiAddress);
        usdc = IERC20(usdcAddress);
        dexContract = IDex(dexContractAddress);
    }

    /**
     * @dev 闪电贷执行回调函数（套利核心逻辑）
     * @param asset 贷款资产地址
     * @param amount 贷款金额
     * @param premium 贷款费用
     * @param initiator 交易发起者
     * @param params 附加参数
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        // 套利操作流程：
        // 1. 存入1000 USDC到交易所（1000000000 = 1000 * 1e6）
        dexContract.depositUSDC(1000000000);
        // 2. 使用USDC购买DAI
        dexContract.buyDAI();
        // 3. 将获得的DAI存入交易所
        dexContract.depositDAI(dai.balanceOf(address(this)));
        // 4. 卖出DAI换回USDC
        dexContract.sellDAI();

        // 计算应还款总额（本金 + 费用）
        uint256 amountOwed = amount + premium;
        // 授权资金池划转还款金额
        IERC20(asset).approve(address(POOL), amountOwed);

        return true;
    }

    /// @dev 发起闪电贷请求
    /// @param _token 要借贷的代币地址
    /// @param _amount 借贷数量
    function requestFlashLoan(address _token, uint256 _amount) public {
        address receiverAddress = address(this);
        POOL.flashLoanSimple(
            receiverAddress,
            _token,
            _amount,
            "",     // 附加参数
            0       // 推荐码
        );
    }

    /// @dev 授权USDC给交易所
    /// @param _amount 授权数量
    function approveUSDC(uint256 _amount) external returns (bool) {
        return usdc.approve(dexContractAddress, _amount);
    }

    /// @dev 查询USDC授权额度
    function allowanceUSDC() external view returns (uint256) {
        return usdc.allowance(address(this), dexContractAddress);
    }

    /// @dev 授权DAI给交易所
    /// @param _amount 授权数量
    function approveDAI(uint256 _amount) external returns (bool) {
        return dai.approve(dexContractAddress, _amount);
    }

    /// @dev 查询DAI授权额度
    function allowanceDAI() external view returns (uint256) {
        return dai.allowance(address(this), dexContractAddress);
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

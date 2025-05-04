// contracts/FlashLoan.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// 导入AAVE V3闪电贷基础合约
import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
// 导入AAVE资金池地址提供者接口
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
// 导入ERC20代币接口
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract FlashLoan is FlashLoanSimpleReceiverBase {
    address payable owner; // 合约所有者地址

    /// @dev 初始化闪电贷合约
    /// @param _addressProvider AAVE资金池地址提供者合约地址
    constructor(address _addressProvider)
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
        owner = payable(msg.sender); // 设置合约部署者为所有者
    }

    /**
     * @dev 闪电贷执行回调函数（核心逻辑）
     * @param asset 抵押资产地址
     * @param amount 借款金额
     * @param premium 借款费用
     * @param initiator 交易发起者地址
     * @param params 附加参数
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        // 计算应还款总额（本金 + 费用）
        uint256 amountOwed = amount + premium;
        // 授权资金池合约划转还款金额
        IERC20(asset).approve(address(POOL), amountOwed);
        return true;
    }

    /// @dev 发起闪电贷请求
    /// @param _token 要借贷的代币地址
    /// @param _amount 借贷数量
    function requestFlashLoan(address _token, uint256 _amount) public {
        address receiverAddress = address(this);
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = "";
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    /// @dev 查询合约持有的代币余额
    /// @param _tokenAddress 代币地址
    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    /// @dev 提取合约中的代币（仅限所有者）
    /// @param _tokenAddress 要提取的代币地址
    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    /// @dev 权限修饰符：仅允许合约所有者调用
    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    /// @dev 接收以太币的回退函数
    receive() external payable {}
}

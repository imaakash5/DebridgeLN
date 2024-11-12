// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDlnSource {
    struct OrderCreation {
        address giveTokenAddress;
        uint256 giveAmount;
        bytes takeTokenAddress;
        uint256 takeAmount;
        uint256 takeChainId;
        bytes receiverDst;
        address givePatchAuthoritySrc;
        bytes orderAuthorityAddressDst;
        bytes allowedTakerDst;
        bytes externalCall;
        bytes allowedCancelBeneficiarySrc;
    }

    function createOrder(
        OrderCreation calldata _orderCreation,
        bytes calldata _affiliateFee,
        uint32 _referralCode,
        bytes calldata _permitEnvelope
    ) external payable returns (bytes32);
    function globalFixedNativeFee() external view returns (uint256);
}

contract DlnSwapper is Ownable {
    using SafeERC20 for IERC20;

    bool private _flag = false;
    IDlnSource private dlnSource;
    mapping(address => uint256) private feePerAsset;
    uint256 public adminFee;
    address public feePool;
    mapping(address => bool) public isWhitelistedTarget;
    mapping(address => bool) public isWhitelistedToken;

    modifier nonReentrant() {
        require(!_flag, "Reentrant");
        _flag = true;
        _;
        _flag = false;
    }

    constructor(address dlnSourceAddress_, uint256 adminFee_, address feePool_) Ownable(msg.sender) {
        _zeroCheck(dlnSourceAddress_);
        dlnSource = IDlnSource(dlnSourceAddress_);
        adminFee = adminFee_;
        feePool = feePool_;
    }

    function updateAssetFee(address asset_, uint256 fee_) external onlyOwner {
        feePerAsset[asset_] = fee_;
    }

    function getFeePerAsset(address asset_) public view returns (uint256 fee_) {
        fee_ = feePerAsset[asset_];
    }

    function updateAdminFee(uint256 adminFee_) external onlyOwner {
        adminFee = adminFee_;
    }

    function setWhitelistedTarget(address target_, bool value_) external onlyOwner {
        isWhitelistedTarget[target_] = value_;
    }

    function setWhitelistedToken(address[] memory token_, bool[] memory value_) external onlyOwner {
        require(token_.length == value_.length, "Length mismath");
        for (uint256 i = 0; i < token_.length; i++) {
            isWhitelistedToken[token_[i]] = value_[i];
        }
    }

    function placeOrder(
        IDlnSource.OrderCreation memory orderCreation_,
        bytes memory affiliateFee_,
        uint32 referralCode_,
        bytes memory permitEnvelope_
    ) public payable nonReentrant returns (bytes32) {
        uint256 protocolFee = dlnSource.globalFixedNativeFee();
        uint256 assetAmount = orderCreation_.giveAmount;
        address giveAsset = orderCreation_.giveTokenAddress;
        require(isWhitelistedToken[giveAsset], "Invalid Token");
        uint256 totalAmount = totalTokensForApproval(giveAsset, assetAmount);
        uint256 totalValue;

        if (giveAsset != address(0)) {
            IERC20(giveAsset).safeTransferFrom(msg.sender, address(this), totalAmount);
            IERC20(giveAsset).safeIncreaseAllowance(address(dlnSource), assetAmount);
            totalValue = protocolFee;
        } else {
            require(msg.value >= totalAmount, "InSufficient ETH");
            totalValue = protocolFee + assetAmount;
        }
        require(address(this).balance >= totalValue, "Insufficient ETH for protocol");

        return dlnSource.createOrder{value: totalValue}(orderCreation_, affiliateFee_, referralCode_, permitEnvelope_);
    }

    function placeOrder(
        bytes calldata targetData_,
        address target_,
        uint256 targetValue_,
        address giveToken_,
        uint256 giveTokenAmount_
    ) external payable nonReentrant {
        require(isWhitelistedTarget[target_], "Target not whitelisted");
        require(isWhitelistedToken[giveToken_], "Invalid Token");

        uint256 contractBal = address(this).balance - msg.value;
        uint256 protocolFee = dlnSource.globalFixedNativeFee();
        uint256 totalAmount = totalTokensForApproval(giveToken_, giveTokenAmount_);

        if (giveToken_ != address(0)) {
            IERC20(giveToken_).safeTransferFrom(msg.sender, address(this), totalAmount);
            IERC20(giveToken_).safeTransfer(feePool, totalAmount - giveTokenAmount_);
            IERC20(giveToken_).safeIncreaseAllowance(target_, giveTokenAmount_);
        } else {
            require(msg.value >= totalAmount, "Insufficient ETH for Tx");
            (bool success,) = payable(feePool).call{value: (totalAmount - giveTokenAmount_)}("");
            require(success);
        }

        require(address(this).balance >= targetValue_, "Insufficient ETH for protocol fee");
        (bool resp,) = target_.call{value: targetValue_}(targetData_);
        require(resp, "Target Call failed");
        uint256 newContractBal = address(this).balance;
        require((contractBal - newContractBal) == protocolFee, "Invalid Order details");
    }

    function withdrawETH(address dstAddr_, uint256 amount_) external onlyOwner {
        require(amount_ <= address(this).balance, "Insufficient ETH");
        payable(dstAddr_).transfer(amount_);
    }

    function withdrawToken(address token_, address dstAddr_, uint256 amount_) external onlyOwner {
        _zeroCheck(token_);
        require(amount_ <= IERC20(token_).balanceOf(address(this)), "Insufficient Token");
        IERC20(token_).transfer(dstAddr_, amount_);
    }

    function totalTokensForApproval(address asset_, uint256 amount_) public view returns (uint256 totalTokens_) {
        totalTokens_ = amount_ + getFeePerAsset(asset_) + (amount_ * adminFee / 1e5);
    }

    function getSwappableTokens(address asset_, uint256 amount_) external view returns (uint256 swappableTokens_) {
        swappableTokens_ = (amount_ - getFeePerAsset(asset_)) * 1e5 / (1e5 + adminFee);
    }

    function _zeroCheck(address target_) internal pure {
        require(target_ != address(0), "Invalid Address");
    }

    receive() external payable {}
}

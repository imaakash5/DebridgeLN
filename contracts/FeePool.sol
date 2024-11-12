// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeePool is Ownable {
    constructor() Ownable(msg.sender) {}

    receive() external payable {}

    function withdrawETH(address dstAddr_, uint256 amount_) external onlyOwner {
        require(amount_ <= address(this).balance, "Insufficient ETH");
        payable(dstAddr_).transfer(amount_);
    }

    function withdrawToken(address token_, address dstAddr_, uint256 amount_) external onlyOwner {
        _zeroCheck(token_);
        require(amount_ <= IERC20(token_).balanceOf(address(this)), "Insufficient Token");
        IERC20(token_).transfer(dstAddr_, amount_);
    }

    function _zeroCheck(address target_) internal pure {
        require(target_ != address(0), "Invalid Address");
    }
}

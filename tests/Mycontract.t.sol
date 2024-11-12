//SPDX-License:Identifier
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DlnSwapper, IDlnSource} from "../contracts/DlnSwapper.sol";
import {FeePool} from "../contracts/FeePool.sol";

interface IUSDC {
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract Testmycontract is Test {
    DlnSwapper public swapper;
    FeePool public pool;
    IUSDC private giveToken;
    IDlnSource.OrderCreation private order;
    address public admin = vm.addr(1234);
    address public user1 = vm.addr(6394629);
    address private usdcBasechain = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    //address private usdcEthereumchain = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private usdcAvalanchechain = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    //address private usdcAvalanchechain = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    //address of the base chain
    address private dlnSource_ = 0xeF4fB24aD0916217251F553c0596F8Edc630EB66;

    function setUp() external {
        vm.startPrank(admin);
        giveToken = IUSDC(usdcBasechain);
        // deal(address(giveToken), user1, 253e4);
        pool = new FeePool();
        swapper = new DlnSwapper(dlnSource_, 3000, address(pool));
        swapper.updateAssetFee(usdcBasechain, 3e6);
        //swapper.updateAssetFee(usdcEthereumchain, 3e6);
        swapper.updateAssetFee(address(0), 1e14);
        swapper.setWhitelistedTarget(0xeF4fB24aD0916217251F553c0596F8Edc630EB66, true);
        swapper.setWhitelistedTarget(0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251, true);           
        vm.stopPrank();
    }

    function testsetUp() external view {
        assertEq(swapper.adminFee(), 3000);
        assertEq(swapper.getFeePerAsset(usdcBasechain), 3e6);
    }

    function test_placeOrder() external {
        //create order
        order = IDlnSource.OrderCreation({
            giveTokenAddress: address(giveToken),
            giveAmount: 25000000000, //USDC address
            takeTokenAddress: abi.encodePacked(usdcAvalanchechain),
            takeAmount: 249975400,
            takeChainId: 43114,
            receiverDst: abi.encodePacked(user1),
            givePatchAuthoritySrc: user1,
            orderAuthorityAddressDst: abi.encodePacked(user1),
            allowedTakerDst: "",
            externalCall: "",
            allowedCancelBeneficiarySrc: ""
        });
        //dealing USDC to user1
        deal(usdcBasechain, user1, 30000e6);
        assertEq(giveToken.balanceOf(user1), 30000e6);
        uint256 totalTokens = 25000e6 + swapper.getFeePerAsset(usdcBasechain) + (25000e6 * swapper.adminFee() / 1e5);
        console.log("Total Tokens: ", totalTokens);
        //approval to order.giveTokenAddress
        vm.prank(user1);
        giveToken.approve(address(swapper), totalTokens);
        assertEq(giveToken.allowance(user1, address(swapper)), totalTokens);

        deal(address(swapper), 1e18);
        //placing order
        vm.prank(user1);
        swapper.placeOrder(order, "", 0, "");
        //checking user1 tokens
        assertEq(giveToken.balanceOf(user1), 30000e6 - totalTokens);
        //checking bal of swapper
        assertEq(giveToken.balanceOf(address(swapper)), totalTokens - 25000e6);
        //checking eth balance of swapper
        assertEq(address(swapper).balance, 1e18 - 1e15);
    }

    // function test_placeOrder_Eth() external {
    //     //create order
    //     order = IDlnSource.OrderCreation({
    //         giveTokenAddress: address(0), //ETH
    //         giveAmount: 10e18,
    //         takeTokenAddress: abi.encodePacked(usdcAvalanchechain),
    //         takeAmount: 249975400,
    //         takeChainId: 43114,
    //         receiverDst: abi.encodePacked(address(user1)),
    //         givePatchAuthoritySrc: address(user1),
    //         orderAuthorityAddressDst: abi.encodePacked(address(user1)),
    //         allowedTakerDst: "",
    //         externalCall: "",
    //         allowedCancelBeneficiarySrc: ""
    //     });
    //     //dealing ETH to user1
    //     deal(user1, 15e18);
    //     assertEq(user1.balance, 15e18);
    //     uint256 totalTokens = swapper.totalTokensForApproval(address(0), 10e18);
    //     console.log("Total Tokens: ", totalTokens);

    //     deal(address(swapper), 1e18);
    //     //placing order
    //     vm.prank(user1);
    //     swapper.placeOrder{value: totalTokens}(order, "", 0, "");
    //     //checking user1 balance
    //     assertEq(user1.balance, 15e18 - totalTokens);
    //     //checking bal of swapper
    //     assertEq(address(swapper).balance, totalTokens - 10e18 + (1e18 - 1e15));
    // }

    // function test_placeOrder_target() external {
    //     uint256 totalTokens = swapper.totalTokensForApproval(address(0), 1000000000000000000);
    //     swapper.placeOrder{value: totalTokens}(
    //         "0x4d8160ba00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000000001400000000000000000000000001111111254eeb25477b68fb85ed929f73a9605820000000000000000000000000000000000000000000000000000000000000160000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000000000000000000000000000000000000091ee729e000000000000000000000000f54edcbefbdab54ea8fdfe279c9a518a4bca7d01000000000000000000000000ef4fb24ad0916217251f553c0596f8edc630eb660000000000000000000000000000000000000000000000000000000000000740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005a812aa3caf000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000663dc15d3c1ac63ff12e45ab68fea3f0a883c2510000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000000000091ee729d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041a0000000000000000000000000000000000000000000000000000000003fc00a0c9e75c48000000000000000008020000000000000000000000000000000000000000000000000003ce0001bd00a007e5c0d200000000000000000000000000000000000000000000019900006900001a40414200000000000000000000000000000000000006d0e30db002a0000000000000000000000000000000000000000000000000000000001cfc7df2ee63c1e501f6c0a374a483101e04ef5f7ac9bd15d9142bac954200000000000000000000000000000000000006512001538aa697ce8cc8252c70c41452dae86ce22a3ed9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca00a4a5dcbcdf000000000000000000000000d9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000bb8b2da5db110ad625270061e81987ce342677c30000000000000000000000001111111254eeb25477b68fb85ed929f73a960582ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0c9e75c48000000000000002010020000000000000000000000000000000000000000000001e30001420000a100a007e5c0d200000000000000000000000000000000000000000000000000007d00001a40414200000000000000000000000000000000000006d0e30db002a00000000000000000000000000000000000000000000000000000000004a32672ee63c1e581b4cb800910b228ed3d0834cf79d697127bbb00e542000000000000000000000000000000000000061111111254eeb25477b68fb85ed929f73a96058200a007e5c0d200000000000000000000000000000000000000000000000000007d00001a40414200000000000000000000000000000000000006d0e30db002a00000000000000000000000000000000000000000000000000000000025199231ee63c1e58172ab388e2e2f6facef59e3c3fa2c4e29011c2d3842000000000000000000000000000000000000061111111254eeb25477b68fb85ed929f73a96058200a007e5c0d200000000000000000000000000000000000000000000000000007d00001a40414200000000000000000000000000000000000006d0e30db002a0000000000000000000000000000000000000000000000000000000004a2f9541ee63c1e581b2cc224c1c9fee385f8ad6a55b4d94e92359dc5942000000000000000000000000000000000000061111111254eeb25477b68fb85ed929f73a960582000000000000fef84ee90000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000404b930370100000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000191b9de7ca30000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003600000000000000000000000000000000000000000000000000000000000000380000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000000000000000000000000000000000000091ee729e00000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000091be2dc60000000000000000000000000000000000000000000000000000000000736f6c00000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000f54edcbefbdab54ea8fdfe279c9a518a4bca7d0100000000000000000000000000000000000000000000000000000000000001e00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000020c6fa7af3bedbad3a3d65f36aabc97431b1bbe4c2d2f6e0e47ca60203452f5d610000000000000000000000000000000000000000000000000000000000000020791b1cd0bf1911f23a654432a7c09bfd32cc0dd5746b168d2ca732b7b63ed3430000000000000000000000000000000000000000000000000000000000000020791b1cd0bf1911f23a654432a7c09bfd32cc0dd5746b168d2ca732b7b63ed3430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000420101000000505c32f829be0100000000000000000000000000c62dbe910000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    //         0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251,
    //         1001000000000000000,
    //         address(0),
    //         1000000000000000000
    //     );
    // }

    // function test_placeOrder_target_noData() external {

    //     deal(user1, 10e18);
    //     uint256 totalTokens = swapper.totalTokensForApproval(address(0), 1e18);
    //     uint256 balBeforeUser = address(user1).balance;
    //     uint256 balBeforeSwapper = address(swapper).balance;
    //     vm.prank(user1);
    //     swapper.placeOrder{value: totalTokens}("",
    //      0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251, 1e18+1e15, address(0), 1e18);
    //     uint256 balAfterUser = address(user1).balance;
    //     uint256 balAfterSwapper = address(swapper).balance;
    //     assertEq(balBeforeUser-balAfterUser, totalTokens);
    //     assertEq(balAfterSwapper-balBeforeSwapper, totalTokens);
    //     console.log("Swapper balance: ", balAfterSwapper);
    // }

    // function test_placeOrder_target_noData_USDC() external {

    //     deal(usdcBasechain, user1, 100e6);
    //     deal(address(swapper), 1e15);
    //     uint256 totalTokens = swapper.totalTokensForApproval(usdcBasechain, 10e6);
    //     uint256 balBeforeUser = IUSDC(usdcBasechain).balanceOf(user1);
    //     uint256 balBeforeSwapper = IUSDC(usdcBasechain).balanceOf(address(swapper));
    //     vm.startPrank(user1);
    //     IUSDC(usdcBasechain).approve(address(swapper), totalTokens);
    //     swapper.placeOrder("",
    //      0x663DC15D3C1aC63ff12E45Ab68FeA3F0a883C251, 1e15, usdcBasechain, 10e6);
    //     uint256 balAfterUser = IUSDC(usdcBasechain).balanceOf(user1);
    //     uint256 balAfterSwapper = IUSDC(usdcBasechain).balanceOf(address(swapper));
    //     assertEq(balBeforeUser-balAfterUser, totalTokens);
    //     assertEq(balAfterSwapper-balBeforeSwapper, totalTokens);
    //     console.log("Swapper balance: ", balAfterSwapper);
    // }

    // function test_withdraw_Tokens() external {
    //     deal(user1, 1e18);
    //     vm.prank(user1);
    //     payable(address(swapper)).transfer(1e18);
    //     vm.prank(swapper.owner());
    //     swapper.withdrawETH(vm.addr(456), 5e17);

    //     assertEq(vm.addr(456).balance, 5e17);
    //     // assertEq(address(swapper).balance, 5e17);

    //     deal(usdcBasechain, address(swapper), 1e7);
    //     vm.prank(swapper.owner());
    //     swapper.withdrawToken(usdcBasechain, vm.addr(1242), 5e6);

    //     assertEq(IUSDC(usdcBasechain).balanceOf(vm.addr(1242)), 5e6);
    // }

    // function test_view_functions() view external {
    //     uint256 amount1 = swapper.totalTokensForApproval(usdcBasechain, 10e6);
    //     uint256 amount2 = swapper.getSwappableTokens(usdcBasechain, amount1);
    //     assertEq(amount2, 10e6);
    // }
}

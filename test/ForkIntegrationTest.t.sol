// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ForkVm {
    function createSelectFork(string calldata rpcUrl) external returns (uint256 forkId);
}

interface IERC20Metadata {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IChainlinkFeed {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract ForkIntegrationTest {
    ForkVm internal constant VM = ForkVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string internal constant MAINNET_RPC = "https://ethereum.publicnode.com";
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_WHALE = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address internal constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    function setUp() public {
        VM.createSelectFork(MAINNET_RPC);
    }

    function testForkUsdcMetadataAndWhaleBalance() public view {
        IERC20Metadata usdc = IERC20Metadata(USDC);
        require(usdc.decimals() == 6, "USDC_DECIMALS");
        require(usdc.totalSupply() > 1_000_000_000e6, "USDC_SUPPLY");
        require(usdc.balanceOf(USDC_WHALE) > 1_000_000e6, "USDC_WHALE");
    }

    function testForkUniswapV2RouterQuote() public view {
        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER);
        require(router.factory() == UNISWAP_V2_FACTORY, "BAD_FACTORY");
        require(router.WETH() == WETH, "BAD_WETH");
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;
        uint256[] memory amounts = router.getAmountsOut(1 ether, path);
        require(amounts[0] == 1 ether, "BAD_INPUT");
        require(amounts[1] > 100e6, "BAD_QUOTE");
    }

    function testForkChainlinkEthUsdFeed() public view {
        IChainlinkFeed feed = IChainlinkFeed(CHAINLINK_ETH_USD);
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        require(feed.decimals() == 8, "FEED_DECIMALS");
        require(answer > 100e8, "BAD_PRICE");
        require(updatedAt > 0, "BAD_UPDATED_AT");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20Base } from "../token/ERC20Base.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { ReentrancyGuard } from "../utils/ReentrancyGuard.sol";

contract RwaVault is ERC20Base, ReentrancyGuard {
    IERC20 public immutable asset;
    address public immutable feeRecipient;
    uint256 public constant performanceFeeBps = 0;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    event FeeUpdated(uint256 performanceFeeBps);

    constructor(IERC20 asset_, address feeRecipient_)
        ERC20Base("RWA Yield Vault Share", "rvRWA", 18)
    {
        asset = asset_;
        feeRecipient = feeRecipient_;
    }

    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply < 1 ? assets : assets * supply / totalAssets();
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply < 1 ? shares : shares * totalAssets() / supply;
    }

    function deposit(uint256 assets, address receiver)
        external
        nonReentrant
        returns (uint256 shares)
    {
        require(assets > 0, "ZERO_ASSETS");
        shares = convertToShares(assets);
        require(shares > 0, "ZERO_SHARES");
        _mint(receiver, shares);
        require(asset.transferFrom(msg.sender, address(this), assets), "TRANSFER_IN");
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        external
        nonReentrant
        returns (uint256 shares)
    {
        shares = convertToShares(assets);
        if (convertToAssets(shares) < assets) shares++;
        require(shares > 0, "ZERO_SHARES");
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            require(allowed >= shares, "ALLOWANCE");
            allowance[owner][msg.sender] = allowed - shares;
        }
        _burn(owner, shares);
        require(asset.transfer(receiver, assets), "TRANSFER_OUT");
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }
}

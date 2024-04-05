// SPDX-License-Identifier: MIT
// This contract limit amount ETH of each address can mint
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./fair-launch-uniswap-v2.sol";


contract LimitAmountFairLaunchToken is FairLaunchToken {
    using SafeERC20 for IERC20;

    uint256 public eachAddressLimitEthers;

    constructor(
        uint256 _price,
        uint256 _amountPerUnits,
        uint256 totalSupply,
        uint256 _treasuryPercentage,
        uint256 _teamPercentage,
        address _teamWallet,
        address _treasuryWallet,
        address _launcher,
        address _uniswapRouter,
        address _uniswapFactory,
        string memory _name,
        string memory _symbol,

        uint256 _eachAddressLimitEthers
    )
        FairLaunchToken(
            _price,
            _amountPerUnits,
            totalSupply,
            _treasuryPercentage,
            _teamPercentage,
            _teamWallet,
            _treasuryWallet,
            _launcher,
            _uniswapRouter,
            _uniswapFactory,
            _name,
            _symbol
        )
    {
        eachAddressLimitEthers = _eachAddressLimitEthers;
    }

    function mint() internal override nonReentrant {
        require(msg.value >= price, "FairMint: value not match");
        require(!_isContract(msg.sender), "FairMint: can not mint to contract");
        require(msg.sender == tx.origin, "FairMint: can not mint to contract.");
        // not start
        require(!started, "FairMint: already started");

        uint256 units = msg.value / price;
        uint256 realCost = units * price;
        uint256 refund = msg.value - realCost;

        require(
            minted + units * amountPerUnits <= mintLimit,
            "FairMint: exceed max supply"
        );

        require(
            balanceOf(msg.sender) * price / amountPerUnits  + realCost <= eachAddressLimitEthers,
            "FairMint: exceed max mint"
        );

        _transfer(address(this), msg.sender, units * amountPerUnits);
        minted += units * amountPerUnits;

        emit FairMinted(msg.sender, units * amountPerUnits, realCost);

        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }
}
// powered by WRB
// https://github.com/WhiteRiverBay/evm-fair-launch

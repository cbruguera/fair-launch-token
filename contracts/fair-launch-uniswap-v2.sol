// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";


contract FairLaunchToken is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public price;
    uint256 public amountPerUnits;

    uint256 public mintLimit;
    uint256 public minted;

    bool public started;
    address public launcher;

    address public uniswapRouter;
    address public uniswapFactory;

    uint256 treasuryPercentage;
    uint256 teamPercentage;
    address teamWallet;
    address treasuryWallet;

    event FairMinted(address indexed to, uint256 amount, uint256 ethAmount);

    event LaunchEvent(
        address indexed to,
        uint256 amount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event RefundEvent(address indexed from, uint256 amount, uint256 bnb);

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
        string memory _symbol
    ) 
        ERC20(_name, _symbol) 
    {
        price = _price;
        amountPerUnits = _amountPerUnits;
        started = false;

        _mint(address(this), totalSupply);
        
        // 50% of total supply for mint
        mintLimit = (totalSupply) / 2;
        
        // set launcher
        launcher = _launcher;
        
        // set uniswap router
        uniswapRouter = _uniswapRouter;
        uniswapFactory = _uniswapFactory;

        treasuryPercentage = _treasuryPercentage;
        teamPercentage = _teamPercentage;
        teamWallet = _teamWallet;
        treasuryWallet = _treasuryWallet;
    }

    receive() external payable {
        if (msg.value == 0.0005 ether && !started) {
            if (minted == mintLimit) {
                start();
            } else {
                require(
                    msg.sender == launcher,
                    "FairMint: only launcher can start"
                );
                start();
            }
        } else {
            mint();
        }
    }

    function mint() virtual internal nonReentrant {
        require(msg.value >= price, "FairMint: value not match");
        require(!_isContract(msg.sender), "FairMint: can not mint to contract");
        require(msg.sender == tx.origin, "FairMint: can not mint to contract.");
        require(!started, "FairMint: already started");

        uint256 units = msg.value / price;
        uint256 realCost = units * price;
        uint256 refund = msg.value - realCost;

        require(
            minted + units * amountPerUnits <= mintLimit,
            "FairMint: exceed max supply"
        );

        minted += units * amountPerUnits;
        _transfer(address(this), msg.sender, units * amountPerUnits);

        emit FairMinted(msg.sender, units * amountPerUnits, realCost);

        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }

    function start() internal {
        require(!started, "FairMint: already started");

        address _weth = IUniswapV2Router02(uniswapRouter).WETH();
        address _pair = IUniswapV2Factory(uniswapFactory).getPair(
            address(this),
            _weth
        );

        if (_pair == address(0)) {
            _pair = IUniswapV2Factory(uniswapFactory).createPair(
                address(this),
                _weth
            );
        }
        _pair = IUniswapV2Factory(uniswapFactory).getPair(address(this), _weth);
        assert(_pair != address(0));
        started = true;

        // funds allocation
        uint256 totalETH = address(this).balance;
        uint256 treasuryETH = (totalETH * treasuryPercentage) / 100; 
        uint256 teamETH = (totalETH * teamPercentage) / 100; 
        uint256 presaleETH = totalETH - treasuryETH - teamETH; 

        uint256 tokenBalance = balanceOf(address(this));
        uint256 treasuryTokens = (tokenBalance * treasuryPercentage) / 100;
        uint256 teamTokens = (tokenBalance * teamPercentage) / 100; 
        uint256 presaleTokens = tokenBalance - treasuryTokens - teamTokens;

        _transfer(address(this), treasuryWallet, treasuryTokens);
        _transfer(address(this), teamWallet, teamTokens);

        // add liquidity
        IUniswapV2Router02 router = IUniswapV2Router02(uniswapRouter);
        //uint256 diff = balance - minted;
    
        //_burn(address(this), diff);
        _approve(address(this), uniswapRouter, type(uint256).max);

        (uint256 tokenAmount, uint256 ethAmount, uint256 liquidity) = router
            .addLiquidityETH{value: presaleETH}(
                address(this), // token
                presaleTokens, // tokens desired
                presaleTokens, // token min
                address(this).balance, // eth min
                address(this), // lp to
                block.timestamp + 1 days // deadline
            );

        payable(teamWallet).transfer(teamETH);
        payable(treasuryWallet).transfer(treasuryETH);

        emit LaunchEvent(address(this), tokenAmount, ethAmount, liquidity);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20) {
        // if not started, only allow refund
        if (!started) {
            if (to == address(this) && from != address(0)) {
                // refund deprecated
            } else {
                // if it is not refund operation, check and revert.
                if (from != address(0) && from != address(this)) {
                    // if it is not INIT action, revert. from address(0) means INIT action. from address(this) means mint action.
                    revert("FairMint: all tokens are locked until launch.");
                }
            }
        } else {
            if (to == address(this) && from != address(0)) {
                revert(
                    "FairMint: You can not send token to contract after launched."
                );
            }
        }
        super._update(from, to, value);
        if (to == address(this) && from != address(0)) {
            _refund(from, value);
        }
    }

    function _refund(address from, uint256 value) internal nonReentrant {
        require(!started, "FairMint: already started");
        require(!_isContract(from), "FairMint: can not refund to contract");
        require(from == tx.origin, "FairMint: can not refund to contract.");
        require(value >= amountPerUnits, "FairMint: value not match");
        require(value % amountPerUnits == 0, "FairMint: value not match");

        uint256 _bnb = (value / amountPerUnits) * price;
        require(_bnb > 0, "FairMint: no refund");

        minted -= value;
        payable(from).transfer(_bnb);
        emit RefundEvent(from, value, _bnb);
    }

    // is contract
    function _isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
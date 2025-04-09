// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin-contracts-5.2.0/token/ERC20/ERC20.sol";

contract Mock_USDT is ERC20 {
    uint8 public _decimals = 6;

    constructor() ERC20("Test USDT", "T_USDT") {}
    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        _burn(_from, _amount);
    }

    function setDecimals(uint8 _newDecimals) external {
        _decimals = _newDecimals;
    }

    function decimals() override view public returns(uint8) {
        return _decimals;
    }
}

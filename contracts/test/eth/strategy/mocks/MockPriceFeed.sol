// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceFeed} from "reka-common/pricefeed/IPriceFeed.sol";

contract MockPriceFeed is IPriceFeed {
    uint64 public hb;
    uint256 public p;
    uint64 public ts;
    
    constructor(uint64 _hb, uint256 _p) { 
        hb = _hb; 
        p = _p; 
        ts = uint64(block.timestamp); 
    }
    
    function set(uint256 _p, uint64 _ts) external { 
        p = _p; 
        ts = _ts; 
    }
    
    function priceWad() external view returns (uint256, uint64) { 
        return (p, ts); 
    }
    
    function heartbeat() external view returns (uint64) { 
        return hb; 
    }
    
    function quote(uint256 base, uint8 bd, uint8 qd) external view returns (uint256, uint64) {
        // Simplified: assume bd=qd for tests
        return ((base * p) / 1e18, ts);
    }
}
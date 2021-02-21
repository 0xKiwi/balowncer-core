// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is disstributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.5.12;

// Builds new BPools, logging their addresses and providing `isBPool(address) -> (bool)`

import "./BPool.sol";
import "./BCreate2.sol";

contract BFactory is BBronze {
    event LOG_NEW_POOL(
        address indexed caller,
        address indexed pool
    );

    event LOG_BLABS(
        address indexed caller,
        address indexed blabs
    );

    bytes4 private constant POOL_INIT_SIGNITURE = bytes4(keccak256("initialize(address)"));

    address public bPoolImpl;
    uint256 public deployNonce;
    mapping(address=>bool) private _isBPool;

    function isBPool(address b)
        external view returns (bool)
    {
        return _isBPool[b];
    }

    function make_payable(address x) internal pure returns (address payable) {
        return address(uint160(x));
    }

    function newBPool()
        external
        returns (BPool)
    {
        bytes memory bytecode = type(InitializableProxy).creationCode;
        // unique salt required for each protocol, salt + deployer decides contract address
        bytes32 salt = keccak256(abi.encodePacked(deployNonce++));
        address proxyAddr = BCreate2.deploy(salt, bytecode);
        bytes memory initData = abi.encodeWithSelector(POOL_INIT_SIGNITURE, address(this));
        InitializableProxy(make_payable(proxyAddr)).initialize(bPoolImpl, initData);
        BPool proxyPool = BPool(uint160(proxyAddr));
        _isBPool[proxyAddr] = true;
        emit LOG_NEW_POOL(msg.sender, proxyAddr);
        proxyPool.setController(msg.sender);
        return proxyPool;
    }

    address private _blabs;

    constructor() public {
        _blabs = msg.sender;
        BPool bpool = new BPool();
        bpool.initialize(address(0));
        bPoolImpl = address(bpool);
    }

    function getBLabs()
        external view
        returns (address)
    {
        return _blabs;
    }

    function setBLabs(address b)
        external
    {
        require(msg.sender == _blabs, "ERR_NOT_BLABS");
        emit LOG_BLABS(msg.sender, b);
        _blabs = b;
    }

    function collect(BPool pool)
        external 
    {
        require(msg.sender == _blabs, "ERR_NOT_BLABS");
        uint collected = IERC20(pool).balanceOf(address(this));
        bool xfer = pool.transfer(_blabs, collected);
        require(xfer, "ERR_ERC20_FAILED");
    }
}

pragma solidity ^0.4.23;

import "./role/Attendee.sol";
import "./role/Admin.sol";
import "./status/Status.sol";
import "./util/Math.sol";


/**
 * @title PartyProxy
 * the proxy of party
 */

contract PartyProxy {

    address public contractAddress;//合约地址
    bytes4  public methodCode;//合约方法

    /* constructor function */
    constructor (
        address _contractAddress,
        bytes4 _methodCode
    ) public {
        require(_contractAddress != address(0));

        contractAddress = _contractAddress;
        methodCode = _methodCode;
    }

    function () payable public {//降低参会者报名门槛，只用发起转账就可以报名
        assert(contractAddress.call.value(msg.value)(methodCode, msg.sender));// 因为调用的合约地址是我们自己指定的，不会是恶意地址，所以不需要指定gas限制
    }

}

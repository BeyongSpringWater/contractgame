pragma solidity ^0.4.23;

import "./Owner.sol";


/**
 * @title Admin
 * the admin of party
 */
contract Admin is Owner {

  mapping(address => bool) admins;//会议管理员

  event AdminGranted(address indexed grantee);
  event AdminRevoked(address indexed grantee);

  constructor () public {
    admins[msg.sender]=true;//owner 默认也是管理者
  }


  modifier onlyAdmin() {//只能是admin权限控制
    require(isAdmin(msg.sender));
    _;
  }

  function isAdmin(address _addr) view public returns (bool){ // 查看改地址是不是管理员
    return (admins[_addr] == true);
  }

  function grant(address newAdmin) external onlyOwner{//新增管理员
    require(!admins[newAdmin]);

    admins[newAdmin] = true;

    emit AdminGranted(newAdmin);
  }

  function revoke(address oldAdmin) external onlyOwner{//撤销指定管理员
    require(admins[oldAdmin]);

    admins[oldAdmin] = false;

    emit AdminRevoked(oldAdmin);
  }
}

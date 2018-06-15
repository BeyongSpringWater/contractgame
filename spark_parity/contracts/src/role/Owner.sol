pragma solidity ^0.4.23;



/**
 * @title Owner
 * the owner of party
 */
contract Owner {

  address public owner;

  constructor () public {
    owner = msg.sender;
  }

  modifier onlyOwner {//只能是owner权限控制
    require(msg.sender == owner);
    _;
  }

  function changeOwner(address _newOwner) external onlyOwner {//改变owner所有者
    owner = _newOwner;
  }

}

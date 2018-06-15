pragma solidity ^0.4.23;

import "./Owner.sol";


/**
* @title Attendee
* attendees of parity
*/
contract Attendee  is Owner{

    struct AttendeeInfo {//参会者信息
        address addr;
        bool isAttended;
        bool isReturned;
    }

    mapping (address => AttendeeInfo) public attendeeMap;//参会者集合

    uint256 public totalOfAttendee;//参会人数限制
    uint256 public numOfApplied;//已报名的人数
    uint256 public numOfAttended;//已参会人数


    constructor (uint256 _totalOfAttendee) public {
        require(_totalOfAttendee > 0);

        totalOfAttendee = _totalOfAttendee;
    }


    function isApplied(address _addr) view public returns (bool){ //是否已经申请报名
        return attendeeMap[_addr].addr != address(0);
    }

    function isAttended(address _addr) view public returns (bool){//是否已经参加会议
        return isApplied(_addr) && attendeeMap[_addr].isAttended;
    }

    function isReturned(address _addr) view public returns (bool){//是否已经返回押金
        return isApplied(_addr) && attendeeMap[_addr].isReturned;
    }


    function updateAttendeeApplied(address _address) internal{//参会人申请注册
        require(numOfApplied < totalOfAttendee);

        numOfApplied++;
        attendeeMap[_address] = AttendeeInfo(_address, false, false);
    }

    function updateAttendeeIsReturned(address _address)  internal {//更新是否返回押金状态

        require(!isReturned(_address));

        attendeeMap[_address].isReturned = true;
    }


    function updateAttendeeTotalOfAttendee(uint256 _totalOfAttendee) internal {//设置参会者人数限制
        require(_totalOfAttendee >= numOfApplied);

        totalOfAttendee = _totalOfAttendee;
    }



    function updateAttendeeAttendedList(address[] _addressList) internal {//参会人出席会议确认
        for(uint i=0;i<_addressList.length;i++){
            address _address = _addressList[i];
            require(isApplied(_address));
            require(!isAttended(_address));

            attendeeMap[_address].isAttended = true;
            numOfAttended++;
        }
    }



}

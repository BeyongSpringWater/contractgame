pragma solidity ^0.4.23;

import "./role/Attendee.sol";
import "./role/Admin.sol";
import "./status/Status.sol";
import "./util/Math.sol";

/**
 * @title Parity
 * join party by smart party
 */

contract Party is Status, Admin, Attendee {

    string public name;//会议名称
    uint256 public applyFee; //每个参会者申请会议收费标准
    uint256 public returnBonus; //返还给每个参会者的押金和奖励

    uint256 public costFee; //每一个参会者申请费中不会返还的成本费用,除非会议取消

    uint256 public ownerBalance; //归属主办方用于举办会议成本的总额度(所有者权益)
    uint256 public liabBalance; //主办方需要给用户的总额度(负债)


    /* constructor function */
    constructor (
        string _name,
        uint256 _totalOfAttendee,
        uint256 _applyFee,
        uint256 _returnBonus
    ) Attendee(_totalOfAttendee) public {
        require(_applyFee >= _returnBonus);

        name = _name;
        applyFee = _applyFee;
        returnBonus = _returnBonus;
        costFee = Math.safeSub(applyFee, returnBonus);
    }


    event ApplyEvent(address _addr, string _encryption);
    event AttendEvent(address[] _addrs);

    event ApplyEndEvent();
    event CancelEvent();
    event FinishEvent();

    event ReturnBonusEvent(address _addr, uint256 _returnBonus);
    event UpdateTotalOfAttendeeEvent(address _addr, uint256 _totalOfAttendee);

    event FreezeContractEvent();
    event UnFreezeContractEvent();

    function apply(address _address) external payable onlyCanApply{//申请会议报名
        require(_address != address(0));
        require(!isApplied(_address));
        require(msg.value == applyFee);

        updateAttendeeApplied(_address);

        ownerBalance = Math.safeAdd(ownerBalance, costFee);

        emit ApplyEvent(_address, '');
    }

    function getReturnBonus(address _address) external onlyEnded{//防止外部调用恶意地址失败带来的损失(如：重入攻击)，优先使用pull而不是push
        require(_address != address(0));
        require(isApplied(_address));


        updateAttendeeIsReturned(_address);

        _address.transfer(returnBonus);

        emit ReturnBonusEvent(_address, returnBonus);
    }

    function updateAttendedList(address[] _addressList) external onlyActive onlyAdmin {//更新参会者列表
        updateAttendeeAttendedList(_addressList);

        emit AttendEvent(_addressList);
    }

    function applyEnd() external onlyCanApply onlyAdmin {//会议报名时间截止
        updateStatusApplyEnd();//更新合约成取消成状态

        emit ApplyEndEvent();
    }

    function cancel() external onlyActive onlyAdmin {//会议取消
        updateStatusCancel();//更新合约成取消成状态

        returnBonus = applyFee;//取消会议全额退换申请费

        emit CancelEvent();
    }

    function finish(address _address) external onlyActive onlyAdmin {//会议举办完成
        require(numOfAttended > 0);//为增加合约公信力，避免出现主办方恶意不更新或忘记更新参会者名单，不将应该返回给用户的奖励部分送给主办方

        updateStatusFinish();//更新合约成完成状态

        uint256 totalBalance = address(this).balance;//当前合约的所有ETH
        liabBalance = Math.safeSub(totalBalance, ownerBalance);//应该分给参会者的余额

        returnBonus = Math.safeDiv(liabBalance, numOfAttended);//是整除，可能会有小于 参会者人数个 wei的精度损益

        uint256 diffBalance = liabBalance % numOfAttended;//精度损益
        if(diffBalance != 0) {
            ownerBalance = Math.safeAdd(ownerBalance, diffBalance);//损益的精度划给举办方
            liabBalance = Math.safeMul(numOfAttended, returnBonus);//重新计算负债
            assert(totalBalance == Math.safeSub(ownerBalance, liabBalance));//双重检查会计恒等式：资产=负债+所有者权益
        }

        if(ownerBalance > 0) {
            _address.transfer(ownerBalance);//将归属主办方用于举办会议成本的总额度转到指定地址中
            ownerBalance = 0;//因为transfer固定2300gas，以及函数入口有updateStatusFinish防止重入风险，所有可以转账后更新
        }

        emit FinishEvent();
    }

    function updateTotalOfAttendee(uint256 _totalOfAttendee) external onlyActive onlyAdmin {//设置参会者人数限制
        updateAttendeeTotalOfAttendee(_totalOfAttendee);

        emit UpdateTotalOfAttendeeEvent(msg.sender, _totalOfAttendee);
    }

    //合约解冻和冻结功能：防止合约bug异常，给工程师一个补救的机会
    function freezeContract() external onlyUnFreeze onlyOwner{//冻结合约
        updateStatusFreeze();

        emit FreezeContractEvent();
    }

    function unFreezeContract() external onlyFreeze onlyOwner{//解冻合约
        updateStatusUnFreeze();

        emit UnFreezeContractEvent();
    }
}

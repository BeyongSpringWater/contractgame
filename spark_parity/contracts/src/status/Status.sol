pragma solidity ^0.4.23;

/**
 * @title Status
 * the status of stop party
 */
contract Status {

    bool public isApplyEnd;//默认为false,true说明报名已截止,否则还可以继续报名

    bool public isEnded;//默认为false,true说明可以申请拿回押金，否则还不能申请拿回押金
    bool public isCanceled;//默认为false,true说明是取消结束会议的，否则是会议正常结束的

    bool public isFreeze;//默认false，true说明是合约状态冻结，否则是合约状态冻结

    /* Modifiers */
    modifier onlyCanApply {//只能在指定时间内才允许报名的权限控制
        require(!isEnded);
        require(!isFreeze);
        require(!isApplyEnd);//报名截止弃用可有矿工操控的now，改用由主办方触发的方案
        _;
    }

    modifier onlyActive {//只能是该会议还未结束的权限控制
        require(!isEnded);
        require(!isFreeze);
        _;
    }

    modifier onlyEnded {//只能是该会议已经结束的权限控制
        require(isEnded);
        _;
    }

    modifier onlyFreeze {//只能是该会议已被冻结的权限控制
        require(isFreeze);
        _;
    }

    modifier onlyUnFreeze {//只能是该会议未被冻结的权限控制
        require(!isFreeze);
        _;
    }


    function updateStatusApplyEnd() internal {//会议报名截止
        isApplyEnd = true;
    }

    function updateStatusCancel() internal {//取消会议
        isEnded = true;
        isCanceled = true;
    }

    function updateStatusFinish() internal {//结束会议
        isEnded = true;
    }

    function updateStatusFreeze() internal {//冻结合约
        isFreeze = true;
    }

    function updateStatusUnFreeze() internal {//解冻合约
        isFreeze = false;
    }
}

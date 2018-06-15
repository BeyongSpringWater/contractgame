/**
 * @Author: zhicai
 * @Date:   2018-06-13T22:39:50+08:00
 * @Last modified by:   zhicai
 * @Last modified time: 2018-06-14T10:37:57+08:00
 */
import React from 'react';

export default class Header extends React.Component {
    render() {
        const pathName = window.location.pathname;
        return (
            <div className="worldcup__banner">
                <section>
                    <a href="javascript:" className="worldcup__slogan">俄罗斯世界杯 2018</a>
                    &nbsp; 欢迎来到全球首个区块链足球模拟经营类游戏!
                </section>

                <div className="worldcup__header">
                    <div className="worldcup__logo">
                        <i></i>
                        <a href="/">星火世界杯 2018</a>
                    </div>
                    <div id="worldcup__menu">
                        <a href="/signin" className={pathName==='/signin'?'worldcup__menu_current':''}>开启世界杯</a>
                        <a href="/marketplace" className={pathName==='/marketplace'?'worldcup__menu_current':''}>球队市场</a>
                        <a href="/groupstage" className={pathName==='/groupstage'?'worldcup__menu_current':''}>预测</a>
                        <a href="/prizepool" className={pathName==='/prizepool'?'worldcup__menu_current':''}>奖金池公告</a>
                        <a href="/myteam" className={pathName==='/myteam'?'worldcup__menu_current':''}>我的国家队</a>
                        <a href="/usage" className={pathName==='/usage'?'worldcup__menu_current':''}>如何玩？</a>
                    </div>
                    <div></div>
                </div>
            </div>
        );
    }
}

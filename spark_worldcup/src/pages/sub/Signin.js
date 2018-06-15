/**
 * @Author: zhicai
 * @Date:   2018-06-13T22:39:50+08:00
 * @Last modified by:   zhicai
 * @Last modified time: 2018-06-14T22:36:06+08:00
 */
import React from 'react';
import Web3 from 'web3';

export default class Signin extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            hasLogin: false,
            walletAddress: '0x4305C293b65a9615F86FA064b5cDBeA64406ce82'
        };
    }

    componentDidMount() {
        let hasLogin = false;
        let checkAccount = () => {
            if (typeof web3 !== 'undefined') {
                window.web3 = new Web3(window.web3.currentProvider);
                window.web3.eth.getAccounts((error, accounts) => {
                    if (accounts.length === 0) {
                        hasLogin = false;
                        this.setState({
                            hasLogin: false
                        });
                    } else {
                        hasLogin = true;
                        this.setState({
                            hasLogin: true,
                            walletAddress: accounts[0]
                        });
                    }
                })
            } else {
                hasLogin = false;
                console.log('No web3? You should consider trying MetaMask!')
            }
        };

        let accountInterval = window.setInterval(() => {
            if (hasLogin) {
                window.clearInterval(accountInterval);
            } else {
                checkAccount();
            }
        }, 100);
    }

    render() {
        let Header = (
            <section className="unlogin__header">
                <h3>您的 MetaMask 处于锁定状态！</h3>
                <p>请打开MetaMask-您的浏览器钱包插件解锁！</p>

                <div>
                    <img src="/images/locked-out.svg" />
                </div>
            </section>
        );
        let { hasLogin, walletAddress } = this.state;

        if (hasLogin) {
            Header = (
                <section className="unlogin__header">
                    <h4>区块链世界杯，用ETH购买或投注你支持的球队!</h4>
                    <p>你的钱包地址 <span>{walletAddress}</span></p>

                    <div className="worldcup__signin">
                        <img src="/images/fifaicon.png" />
                    </div>

                    <div></div>
                    <a className="button__largest" href="/marketplace" style={{'width': '20rem'}}>球队市场</a>
                </section>
            );
        }
        return (
            <div>
                {Header}
            </div>
        );
    }
}

/**
 * @Author: zhicai
 * @Date:   2018-06-13T22:39:50+08:00
 * @Last modified by:   zhicai
 * @Last modified time: 2018-06-13T23:14:09+08:00
 */
import React from 'react';
import axios from 'axios';
import { notification } from 'antd';
import 'antd/dist/antd.css';
import CONFIG from '../../components/common';

const { formatPrice, contractAddress, httpProvider } = CONFIG;

export default class Marketplace extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            hasLogin: false,
            walletAddress: '',
            teams: [],
            showLoading: true
        };
    }

    componentDidMount() {
        this.renderTeams();
    }

    buyTeam = (team) => {
        let copyTeams = this.state.teams;
        let teamId = parseInt(team._tokenId);
        let teamPrice = team._price;
        let teamName = team._name;
        let teamOwner = team._owner;
        let currentAccount;

        if (window.worldcupContract && window.web3) {
            window.web3.eth.getAccounts((error, accounts) => {
                if (accounts && accounts.length) {
                    console.log(accounts, teamPrice);
                    currentAccount = accounts[0];

                    // 如果球队的owner和当前账号为同一人，不能购买
                    if (currentAccount.toLowerCase() === teamOwner.toLowerCase()) {
                        notification.warning({
                            message: '失败!',
                            description: '你已经是该球队的拥有者!'
                        });
                        return;
                    }

                    window.worldcupContract.methods.buyTeam(teamId).send({
                        from: currentAccount,
                        value: teamPrice
                    }).then(receipt => {
                        notification.success({
                            message: '恭喜!',
                            description: `你已成功购买了 ${teamName}!`,
                        });
                        // 重新获取当前的球队的价格
                        copyTeams = copyTeams.map(team => {
                            if (team._tokenId == teamId) {
                                team.price = formatPrice(team._price * 2);
                                team._owner = currentAccount;
                            }
                            return {
                                ...team
                            };
                        });
                        this.setState({ teams: copyTeams });
                    }).catch(err => {
                        notification.error({
                            message: '失败!',
                            description: '购买失败，请检查您的钱包!'
                        });
                    });
                }
            });
        }
    }

    // 渲染球队
    renderTeams() {
        let Web3 = require('web3');
        // 创建web3对象
        // let web3 = new Web3();
        let worldcupContract = null;
        let web3Provider;
        let worldcupTeams = [];

        // Is there an injected web3 instance?
        if (typeof window.web3 !== 'undefined') {
            web3Provider = window.web3.currentProvider;
        } else {
            // If no injected web3 instance is detected, fall back to Ganache
            web3Provider = new Web3.providers.HttpProvider(httpProvider);
        }

        var web3 = new Web3(web3Provider);

        axios.get('/data/SparkCup.json').then(res => {
            let data = res.data;
            let SparkCup = new web3.eth.Contract(data.abi, contractAddress);
            let getAllTeamsPromise = [];

            worldcupContract = SparkCup;
            window.worldcupContract = worldcupContract;

            // get all teams.
            for (let i = 0; i < 32; i++) {
                getAllTeamsPromise.push(new Promise((resolve, reject) => {
                    worldcupContract.methods.getTeam(i).call().then(result => {
                        worldcupTeams.push({
                            ...result,
                            flag: '/images/' + result._code.toLowerCase() + '.jpeg',
                            key: result._tokenId,
                            price: formatPrice(result._price)
                        });
                        resolve();
                    }).catch(reject);
                }));
            }

            Promise.all(getAllTeamsPromise).then(() => {
                setTimeout(() => {
                    this.setState({
                        teams: worldcupTeams,
                        showLoading: false
                    });
                }, 1000);
            });
        });
    }

    render() {
        let result = [];
        let showLoading = this.state.showLoading;
        let LoadingETH = (
            <div className="marketplace__loading">
                <img src="/images/loader.gif" alt="loading" />
            </div>
        );
        if (this.state && this.state.teams && this.state.teams.length) {
            result = this.state.teams.map(team => (
                <li key={team._tokenId}>
                    <div className="marketplace__box">
                        <span>{team._name}</span>
                        <img src={team.flag} alt="" />
                        <div>
                            价格: {team.price} ETH
                        </div>
                        <button onClick={() => this.buyTeam(team)}>购买</button>
                    </div>
                </li>
            ));
        }

        return (
            <div>
                <section className="marketplace__header">
                    <div>
                        <a href="javascript:">世界杯32强</a>
                    </div>
                </section>
                <ul className="marketplace__teams">
                    { showLoading && LoadingETH }
                    {result}
                </ul>
            </div>
        );
    }
}

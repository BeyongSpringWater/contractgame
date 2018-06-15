import React from 'react';
import axios from 'axios';
import { Row, Col, Button, Input, notification } from 'antd';
import CONFIG from '../../components/common';

const { formatPrice, contractAddress, httpProvider } = CONFIG;

export default class GroupState extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            matches: [],
            showLoading: true
        };
    }
    componentDidMount() {
        let Web3 = require('web3');
        let worldcupContract = null;
        let web3Provider;

        // Is there an injected web3 instance?
        if (typeof window.web3 !== 'undefined') {
            web3Provider = window.web3.currentProvider;
        } else {
            // If no injected web3 instance is detected, fall back to Ganache
            web3Provider = new Web3.providers.HttpProvider(httpProvider);
        }

        var web3 = new Web3(web3Provider);
        window.web3 = web3;

        axios.get('/data/SparkCup.json').then(res => {
            let data = res.data;
            let SparkCup = new web3.eth.Contract(data.abi, contractAddress);

            worldcupContract = SparkCup;
            window.worldcupContract = worldcupContract;

            this.renderMatches();
        });
    }

    renderMatches() {
        axios.get('/data/match.json').then(res => {
            let data = res.data;
            let matches = [];
            if (data.matchs && data.matchs.length) {
                data.matchs.map(match => {
                    if (match.rows && match.rows.length) {
                        match.rows.map(row => {
                            matches.push(row);
                        });
                    }
                });
            }

            let matchLength = matches.length;
            let matchPromises = [];
            let matchPrizePool = [];

            for (let i = 0; i < matchLength; i++) {
                matchPromises.push(new Promise((resolve, reject) => {
                    window.worldcupContract.methods.getMatch(i).call().then(result => {
                        matchPrizePool.push(result);
                        resolve();
                    }).catch(error => {
                        reject();
                    });
                }));
            }

            Promise.all(matchPromises).then(() => {
                for (let i = 0; i < matches.length; i++) {
                    if (matchPrizePool.length > i) {
                        matches[i].prizepool = formatPrice(matchPrizePool[i][5]);
                    } else {
                        matches[i].prizepool = 0;
                    }
                }
                console.log(matchPrizePool);
                setTimeout(() => {
                    this.setState({ matches, showLoading: false });
                }, 1000);
            });
        });
    }

    // update prize pool for the match
    updatePrizePool(matchId) {
        console.log('you trigged updatePrizePool.')
        let copyMatches = this.state.matches;
        window.worldcupContract.methods.getMatch(matchId).call().then(result => {
            console.log(result);
            let currentPrize = formatPrice(result[5]);
            for (let i = 0; i < copyMatches.length; i++) {
                if (copyMatches[i].id == matchId) {
                    copyMatches[i].prizepool = currentPrize;
                }
            }
            this.setState({
                matchs: copyMatches
            });
        }).catch(console.log);
    }

    // bet for the match
    openResult(match, flag) {
        let matchId = match.id;
        let currentAccount;
        let value = 1000000000000000000;
        window.web3.eth.getAccounts((error, accounts) => {
            if (accounts && accounts.length) {
                currentAccount = accounts[0];
                window.worldcupContract.methods.betMatch(matchId, flag).send({
                    from: currentAccount,
                    value: value,
                    // gasPrice: 2000000000,
                    gas: 151214
                }).then(receipt => {
                    notification.success({
                        message: '恭喜!',
                        description: '下注成功！',
                    });
                    setTimeout(this.updatePrizePool.bind(this, matchId), 2000);
                }).catch(err => {
                    notification.error({
                        message: '失败!',
                        description: '下注失败，请检查您的钱包!'
                    });
                });
            }
        });
    }

    render() {
        const { showLoading, matches } = this.state;
        let MatchDOM = [];
        let LoadingETH = (
            <div className="marketplace__loading">
                <img src="/images/loader.gif" alt="loading" />
            </div>
        );
        if (matches && matches.length) {
            MatchDOM = matches.map(m => (
                <Row gutter={16} key={m.id} type="flex" justify="center" align="middle" className="match__item">
                    <Col span={4}>
                        <span className="match__desc">{m.match_desc}</span>
                        <span className="match__time">时间：{(new Date(m.match_date * 1000)).toLocaleDateString()}</span>
                        <span className="match__time">{m.time}</span>
                        <span className="match__prizepool">奖池：{m.prizepool} ETH</span>
                    </Col>
                    <Col span={4}>
                        <img src={m.flag1} />
                        {m.country1}
                    </Col>
                    <Col span={2}>
                        <span className="match__vs">VS</span>
                    </Col>
                    <Col span={4}>
                        <img src={m.flag2} />
                        {m.country2}
                    </Col>
                    <Col span={4}>
                        <Input addonBefore="下注" addonAfter="ETH" defaultValue="1" ref={input => { this.ethInput = input; }} />
                    </Col>
                    <Col span={4}>
                        <Button onClick={() => this.openResult(m, 1)}>{m.country1}赢</Button>
                        <Button onClick={() => this.openResult(m, 2)}>{m.country2}赢</Button>
                        <Button onClick={() => this.openResult(m, 3)}>平局</Button>
                    </Col>
                </Row>
            ));
        }

        return (
            <div className="match__list">
                { showLoading && LoadingETH }
                { MatchDOM }
            </div>
        );
    }
}

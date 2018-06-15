import React from 'react';
import axios from 'axios';
import { Row, Col, Card, Button, notification } from 'antd';
import CONFIG from '../../components/common';

const { formatPrice, contractAddress, httpProvider } = CONFIG;

export default class MyTeam extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            teams: [],
            balance: '0.00',
            showLoading: true
        };
    }

    componentDidMount() {
        let Web3 = require('web3');
        // 创建web3对象
        // let web3 = new Web3();
        let worldcupContract = null;
        let web3Provider;
        let worldcupTeams = [];
        let currentAccount = '';

        // Is there an injected web3 instance?
        if (typeof window.web3 !== 'undefined') {
            web3Provider = window.web3.currentProvider;
        } else {
            // If no injected web3 instance is detected, fall back to Ganache
            web3Provider = new Web3.providers.HttpProvider(httpProvider);
        }

        var web3 = new Web3(web3Provider);

        web3.eth.getAccounts((error, accounts) => {
            if (accounts && accounts.length) {
                currentAccount = accounts[0];
                console.log(currentAccount);

                axios.get('/data/SparkCup.json').then(res => {
                    let data = res.data;
                    let SparkCup = new web3.eth.Contract(data.abi, contractAddress);
                    let getAllTeamsPromise = [];

                    worldcupContract = SparkCup;

                    worldcupContract.methods.getBalance().call({
                        from: currentAccount
                    }).then(result => {
                        console.log(result);
                        if (result) {
                            this.setState({
                                balance: formatPrice(result)
                            })
                        }
                    }).catch(err => {
                        console.log(err);
                    });

                    // get all teams.
                    for (let i = 0; i < 32; i++) {
                        getAllTeamsPromise.push(new Promise((resolve, reject) => {
                            worldcupContract.methods.getTeam(i).call().then(result => {
                                if (result._owner.toLowerCase() === currentAccount.toLowerCase()) {
                                    worldcupTeams.push({
                                        ...result,
                                        flag: '/images/' + result._code.toLowerCase() + '.jpeg',
                                        key: result._tokenId,
                                        price: formatPrice(result._price)
                                    });
                                }
                                resolve();
                            }).catch(reject);
                        }));
                    }

                    Promise.all(getAllTeamsPromise).then(() => {
                        setTimeout(this.setState.bind(this, {
                            teams: worldcupTeams,
                            showLoading: false
                        }), 700);
                    });
                    window.worldcupContract = worldcupContract;
                });
            }
        });
    }

    matchWithDraw() {
        window.worldcupContract.methods.matchWithdraw().call().then(result => {
            console.log(result);
            notification.success({
                message: '恭喜!',
                description: `你已提取成功！`
            });
            this.setState({
                balance: 0
            });
        }).catch(err => {
            console.log(err);
            // notification.error({
            //     message: '失败!',
            //     description: `请检查您的钱包！`
            // });
        });
    }

    render() {
        const { teams, showLoading, balance } = this.state
        let myTeams;
        let LoadingETH = (
            <div className="marketplace__loading">
                <img src="/images/loader.gif" alt="loading" />
            </div>
        );

        if (teams && teams.length) {
            myTeams = teams.map(t => {
                return (
                    <Card title={ t._name } className="myteam__team" key={ t._tokenId }>
                        <img src={ t.flag } alt={ t._name } />
                        <p>购买价格：{ formatPrice(t._price) } ETH</p>
                    </Card>
                );
            });
        } else {
            myTeams = (
                <h3>您尚未购买任何球队！</h3>
            );
        }

        // <Button type="primary" onClick={this.matchWithDraw}>提取</Button>
        //
        return (
            <section className="myteam__box">
                <Row gutter={16} type="flex" justify="left" align="middle">
                    <Col span={4}>
                        账户余额：{ balance } ETH
                    </Col>
                    <Col span={4}>

                    </Col>
                    <Col span={4}>
                    </Col>
                    <Col span={4}>
                    </Col>
                </Row>
                { showLoading && LoadingETH }
                { myTeams }
            </section>
        )
    }
}

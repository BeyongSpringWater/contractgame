import React from 'react';
import axios from 'axios';
import CONFIG from '../../components/common';

const { formatPrice, contractAddress, httpProvider } = CONFIG;

export default class Prizepool extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            finalPoolTotal: '0',
            last16Locked: false,
            last16PoolTotal: '0',
            quarterLocked: false,
            quarterPoolTotal: '0',
            semiLocked: false,
            semiPoolTotal: '0',
            // 十六强
            sixteenTeams: [],
            // 四分之一决赛
            eightTeams: [],
            // 半决赛
            fourTeams: []
        };
    }
    componentDidMount() {
        let Web3 = require('web3');
        // let web3 = new Web3();
        let worldcupContract = null;
        let web3Provider;
        let getAllTeamsPromise = [];
        let worldcupTeams = [];

        // Is there an injected web3 instance?
        if (typeof window.web3 !== 'undefined') {
            web3Provider = window.web3.currentProvider;
        } else {
            // If no injected web3 instance is detected, fall back to Ganache
            web3Provider = new Web3.providers.HttpProvider(httpProvider);
        }
        let web3 = new Web3(web3Provider);

        axios.get('/data/SparkCup.json').then(res => {
            let data = res.data;
            let reward = '';
            let SparkCup = new web3.eth.Contract(data.abi, contractAddress);
            let sixteenTeams = [];
            let eightTeams = [];
            let fourTeams = [];

            worldcupContract = SparkCup;

            // get prize pool
            worldcupContract.methods.getPrizePool().call().then(result => {
                console.log(result);
                this.setState(result);
            });

            // 获取所有的球队
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
                console.log(worldcupTeams);
                worldcupTeams.map(team => {
                    reward = team._rewardCount.toString();
                    if (reward === '1') {
                        sixteenTeams.push(team);
                    }
                    if (reward === '2') {
                        eightTeams.push(team);
                    }
                    if (reward === '3') {
                        fourTeams.push(team);
                    }
                });

                // sixteenTeams.push(worldcupTeams[0]);
                // sixteenTeams.push(worldcupTeams[3]);
                // sixteenTeams.push(worldcupTeams[4]);
                // sixteenTeams.push(worldcupTeams[5]);
                // sixteenTeams.push(worldcupTeams[6]);
                //
                // eightTeams.push(worldcupTeams[1]);
                // eightTeams.push(worldcupTeams[2]);
                // eightTeams.push(worldcupTeams[3]);
                // eightTeams.push(worldcupTeams[4]);
                //
                // fourTeams.push(worldcupTeams[2]);
                // fourTeams.push(worldcupTeams[3]);
                // fourTeams.push(worldcupTeams[4]);
                // fourTeams.push(worldcupTeams[5]);
                // fourTeams.push(worldcupTeams[6]);

                this.setState({ sixteenTeams, eightTeams, fourTeams });
            });
        });
    }
    render() {
        const {
            finalPoolTotal,
            last16Locked,
            last16PoolTotal,
            quarterLocked,
            quarterPoolTotal,
            semiLocked,
            semiPoolTotal,
            sixteenTeams,
            eightTeams,
            fourTeams
        } = this.state;
        let SixteenDOM = <span>暂无赛果！</span>;
        let EightDOM = <span>暂无赛果！</span>;
        let FourDOM = <span>暂无赛果！</span>;

        if (sixteenTeams && sixteenTeams.length) {
            SixteenDOM = sixteenTeams.map(team => (
                <span key={ team._name }>
                    <img src={ team.flag } alt={ team._name } />
                    { team._name }
                </span>
            ));
        }

        if (eightTeams && eightTeams.length) {
            EightDOM = eightTeams.map(team => (
                <span key={ team._name }>
                    <img src={ team.flag } alt={ team._name } />
                    { team._name }
                </span>
            ));
        }

        if (fourTeams && fourTeams.length) {
            FourDOM = fourTeams.map(team => (
                <span key={ team._name }>
                    <img src={ team.flag } alt={ team._name } />
                    { team._name }
                </span>
            ));
        }

        return (
            <div className="prizepool__box">
                <div>
                    <section>
                        奖池金额: {formatPrice(finalPoolTotal)} ETH
                    </section>
                    <section>
                        last16Locked: {last16Locked.toString()}
                    </section>
                    <section>
                        16强奖池: {formatPrice(last16PoolTotal)} ETH
                    </section>
                    <section>
                        quarterLocked: {quarterLocked.toString()}
                    </section>
                    <section>
                        四分之一决赛奖池: {formatPrice(quarterPoolTotal)} ETH
                    </section>
                    <section>
                        semiLocked: {semiLocked.toString()}
                    </section>
                    <section>
                        半决赛奖池: {formatPrice(semiPoolTotal)} ETH
                    </section>
                </div>

                <section className="prizepool__team">
                    <h4>16强：</h4>
                    <div>{ SixteenDOM }</div>
                    <h4>四分之一决赛：</h4>
                    <div>{ EightDOM }</div>
                    <h4>半决赛：</h4>
                    <div>{ FourDOM }</div>
                </section>
            </div>
        );
    }
}

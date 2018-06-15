import React from 'react';
import { BrowserRouter as Router, Route } from 'react-router-dom';
import Homepage from './sub/Homepage';
import Marketplace from './sub/Marketplace';
import Signin from './sub/Signin';
import Header from '../components/layouts/Header';
import Footer from '../components/layouts/Footer';
import Prizepool from './sub/Prizepool';
import GroupStage from './sub/GroupStage';
import MyTeam from './sub/MyTeam';
import Usage from './sub/Usage';

export default class App extends React.Component {
    render() {
        return (
            <Router>
                <section>
                    <Header />
                    <Route exact path='/' component={Homepage} />
                    <Route exact path='/signin' component={Signin} />
                    <Route exact path='/marketplace' component={Marketplace} />
                    <Route exact path='/prizepool' component={Prizepool} />
                    <Route exact path='/groupstage' component={GroupStage} />
                    <Route exact path='/myteam' component={MyTeam} />
                    <Route exact path='/usage' component={Usage} />
                    <Footer />
                </section>
            </Router>
        )
    }
};

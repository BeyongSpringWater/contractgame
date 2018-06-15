/**
 * @Author: zhicai
 * @Date:   2018-06-05T16:11:53+08:00
 * @Last modified by:   zhicai
 * @Last modified time: 2018-06-07T20:01:23+08:00
 */

var SparkCupToken = artifacts.require("./SparkCup.sol");

module.exports = function(deployer) {
  deployer.deploy(SparkCupToken);
};

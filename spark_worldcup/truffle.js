/**
 * @Author: zhicai
 * @Date:   2018-05-23T11:12:23+08:00
 * @Last modified by:   zhicai
 * @Last modified time: 2018-06-13T19:52:18+08:00
 */

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // for more about customizing your Truffle configuration!
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*", // Match any network id
      //gas: 63000000
      //gasPrice: 10000000000
    }
  }
};

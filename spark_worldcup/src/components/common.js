/**
 * @Author: zhicai
 * @Date:   2018-06-13T22:39:50+08:00
 * @Last modified by:   zhicai
 * @Last modified time: 2018-06-15T10:59:15+08:00
 */
const CONFIG = {
    contractAddress: '0xbd64965f444160fcb22d6659508f9cd68502230a',
    httpProvider: 'http://127.0.0.1:7545',
    formatPrice(price) {
        return price / 1000000000000000000;
    }
};

export default CONFIG;

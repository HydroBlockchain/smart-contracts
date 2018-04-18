const Web3 = require('web3') // web3@1.0.0-beta.33

var gas = 4 * 1e6
var gasPrice = Web3.utils.toWei('2', 'gwei')

module.exports = {
  networks: {
    rinkebyIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 4,
      gas: gas,
      gasPrice: gasPrice
    },
    mainIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 1,
      gas: gas,
      gasPrice: gasPrice
    },
    ganache: {
      host: 'localhost',
      port: 8545,
      network_id: '*'
    }
  }
}

const Web3 = require('web3') // web3@1.0.0-beta.34

var gas = 6 * 1e6
var gasPrice = Web3.utils.toWei('10', 'gwei')

module.exports = {
  networks: {
    rinkebyIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 4,
      gas: 7000000,
      gasPrice: Web3.utils.toWei('1', 'gwei')
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
      port: 8555,
      network_id: '*',
      gas: 7000000
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
}

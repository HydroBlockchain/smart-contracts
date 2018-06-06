const Web3 = require('web3') // web3@1.0.0-beta.34

var gas = 3 * 1e6
var gasPrice = Web3.utils.toWei('15', 'gwei')

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
      port: 8555,
      network_id: '*'
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
}

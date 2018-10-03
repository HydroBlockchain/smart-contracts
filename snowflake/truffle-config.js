const Web3 = require('web3')

var gas = 5.5 * 1e6

module.exports = {
  networks: {
    rinkebyIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 4,
      gas: gas,
      gasPrice: Web3.utils.toWei('2', 'gwei')
    },
    mainIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 1,
      gas: gas,
      gasPrice: Web3.utils.toWei('10', 'gwei')
    },
    ganache: {
      host: 'localhost',
      port: 8555,
      network_id: '*'
    }
  },
  solc: {
    optimizer: {
      version: '0.4.24',
      enabled: true,
      runs: 200
    }
  }
}

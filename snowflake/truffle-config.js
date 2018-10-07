const Web3 = require('web3')

var gas = 6.5 * 1e6

module.exports = {
  networks: {
    rinkebyIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 4,
      timeoutBlocks: 200,
      gas: gas,
      gasPrice: Web3.utils.toWei('2', 'gwei'),
      skipDryRun: true
    },
    mainIPC: {
      host: 'localhost',
      port: 8545,
      network_id: 1,
      timeoutBlocks: 200,
      gas: gas,
      gasPrice: Web3.utils.toWei('8', 'gwei'),
      skipDryRun: true
    },
    ganache: {
      host: 'localhost',
      port: 8555,
      network_id: '*'
    }
  },
  compilers: {
    solc: {
      version: '0.4.25',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
}

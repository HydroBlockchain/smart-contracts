# Raindrop Client
<img src="https://www.hydrogenplatform.com/images/logo_hydro.png">

## Introduction
Our client-facing implementation of Raindrop is a natural successor to legacy two-factor authentication solutions. Applications like [Google Authenticator](https://en.wikipedia.org/wiki/Google_Authenticator) and Authy rely on access to shared secrets, secrets that are vulnerable to hacks and data breaches. With Raindrop, users' secrets never leave their devices. And on the backend, we're using the blockchain to eliminate reliance on trusted third parties while ensuring that users will still be able to verify sign-in requests with the click of a button.

## Contract Address
Raindrop Client is live on the Rinkeby testnet at [0xE4796EA3f49FFc11cb7e02E1e36e881035E28e70](https://rinkeby.etherscan.io/address/0xe4796ea3f49ffc11cb7e02e1e36e881035e28e70).

## Testing With Truffle
- This folder has a suite of tests created through [Truffle](https://github.com/trufflesuite/truffle)
- To run these test:
  - Download the code: `git clone https://github.com/hydrogen-dev/smart-contracts.git`
  - Navigate to the `raindrop-client` folder in your terminal
  - Make sure you have Truffle and [Ganache](https://github.com/trufflesuite/ganache-cli) installed: `npm install -g truffle@4.1.5 ganache-cli`
  - Install web3: `npm install web3@1.0.0-beta.33`
  - Install ethereumjs-util: `npm install ethereumjs-util`
  - Spin up a development blockchain: `ganache-cli --seed hydro`
  - Compile the contracts: `truffle compile`
  - Run the test suite: `truffle test --network ganache`

## Copyright & License
Copyright 2018 The Hydrogen Technology Corporation under the GNU General Public License v3.0.

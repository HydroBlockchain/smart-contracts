# Raindrop Client
<img src="https://www.hydrogenplatform.com/images/logo_hydro.png">

## Introduction
The client-facing implementation of Raindrop is a natural successor to legacy two-factor authentication solutions. Applications like [Google Authenticator](https://en.wikipedia.org/wiki/Google_Authenticator) and Authy rely on access to shared secrets, secrets that are vulnerable to hacks and data breaches. With Raindrop, users' secrets never leave their devices. And on the backend, we're using the blockchain to eliminate reliance on trusted third parties while ensuring that users will still be able to verify sign-in and other requests with the click of a button.

## Contract Address
Raindrop Client is live on the [mainnet](https://etherscan.io/address/0xdf9ecafee99e2954df6258ef85f18cf88462f452) and the [Rinkeby testnet](https://rinkeby.etherscan.io/address/0xf0fbbc0d388d7ed16a02609f639ca049ff28f3ec).

## Testing With Truffle
- This folder has a suite of tests created through [Truffle](https://github.com/trufflesuite/truffle)
- To run these test:
  - Download the code: `git clone https://github.com/hydrogen-dev/smart-contracts.git`
  - Navigate to the `raindrop-client` folder in your terminal
  - Make sure you have Truffle and [Ganache](https://github.com/trufflesuite/ganache-cli) installed: `npm install -g truffle@4.1.5 ganache-cli`
  - Install web3 and ethereumjs-util: `npm install web3@1.0.0-beta.33 ethereumjs-util`
  - Spin up a development blockchain: `ganache-cli --seed hydro`
  - Run the test suite: `truffle test --network ganache`

## Copyright & License
Copyright 2018 The Hydrogen Technology Corporation under the GNU General Public License v3.0.

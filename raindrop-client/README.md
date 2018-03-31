# Raindrop Client
<img src="https://www.hydrogenplatform.com/images/logo_hydro.png">

## Introduction
Our client-facing implementation of Raindrop is a natural successor to legacy two-factor authentication solutions. Applications like [Google Authenticator](https://en.wikipedia.org/wiki/Google_Authenticator) and Authy store shared secrets to identify users, secrets that are vulnerable to hacks and data breaches. With Raindrop, users' secrets never leave their devices. And on the backend, we're using the blockchain to ensure that users will be able to verify sign-in requests with the click of a button, eliminating reliance on trusted third parties.

## Testing With Truffle
- This folder has a suite of tests created through [Truffle](https://github.com/trufflesuite/truffle)
- To run these test:
  - Download the code: `git clone https://github.com/hydrogen-dev/smart-contracts.git`
  - Navigate to the `raindrop-client` folder in your terminal
  - Make sure you have Truffle installed: `npm install -g truffle@4.1.5`
  - Install web3: `npm install web3@1.0.0-beta.33`
  - Spin up a development blockchain: `ganache-cli --seed hydro`
  - `$ truffle compile`
  - `truffle test --network ganache`


## Copyright & License
Copyright 2018 The Hydrogen Technology Corporation under the GNU General Public License v3.0.

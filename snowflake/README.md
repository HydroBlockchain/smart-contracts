# Snowflake
<img src="https://www.hydrogenplatform.com/images/logo_hydro.png">

## Introduction
Snowflake is a hydrid on-/off-chain identity management solution. For more details, see [our whitepaper](https://github.com/hydrogen-dev/hydro-docs/tree/master/Snowflake).

## Contract Address
Coming Soon

## Testing With Truffle
- This folder has a suite of tests created through [Truffle](https://github.com/trufflesuite/truffle). This particular repo requires a beta version of truffle know as [darq-truffle](https://www.npmjs.com/package/darq-truffle).
- To run these tests:
  - Download the code: `git clone https://github.com/hydrogen-dev/smart-contracts.git`
  - Navigate to the `snowflake` folder in your terminal
  - Make sure you have darq-truffle and [Ganache](https://github.com/trufflesuite/ganache-cli) installed: `npm install -g truffle@4.1.13 ganache-cli`
  - Install web3 and ethereumjs-util: `npm install web3@1.0.0-beta.34 ethereumjs-util`
  - Spin up a development blockchain: `ganache-cli --seed hydro --port 8555`
  - Run the test suite: `truffle test --network ganache`

## Copyright & License
Copyright 2018 The Hydrogen Technology Corporation under the GNU General Public License v3.0.

# Snowflake
[![Build Status](https://travis-ci.org/hydrogen-dev/smart-contracts.svg?branch=master)](https://travis-ci.org/hydrogen-dev/smart-contracts)
[![Coverage Status](https://coveralls.io/repos/github/hydrogen-dev/smart-contracts/badge.svg?branch=master)](https://coveralls.io/github/hydrogen-dev/smart-contracts?branch=master)

## Introduction
Snowflake is an ERC-1484 `Provider` that provides on-/off-chain identity management. For more details, see [our whitepaper](https://github.com/hydrogen-dev/hydro-docs/tree/master/Snowflake).

## Contract Address
[Snowflake beta on Rinkeby](https://rinkeby.etherscan.io/address/0x7EdA95f86D49ac97D2142Cb3903915835160efEe)
[Client Raindrop beta on Rinkeby](https://rinkeby.etherscan.io/address/0x7EdA95f86D49ac97D2142Cb3903915835160efEe)

## Testing With Truffle
- This folder has a suite of tests created through [Truffle](https://github.com/trufflesuite/truffle).
- To run these tests:
  - Clone this repo: `git clone https://github.com/hydrogen-dev/smart-contracts.git`
  - Navigate to `smart-contracts/snowflake`
  - Run `npm install`
  - Build dependencies with `npm run build`
  - Spin up a development blockchain: `npm run chain`
  - In another terminal tab, run the test suite: `npm test`

## Copyright & License
Copyright 2018 The Hydrogen Technology Corporation under the GNU General Public License v3.0.

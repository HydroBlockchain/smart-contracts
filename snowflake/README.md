# Snowflake
[![Build Status](https://travis-ci.org/hydrogen-dev/smart-contracts.svg?branch=master)](https://travis-ci.org/hydrogen-dev/smart-contracts)
[![Coverage Status](https://coveralls.io/repos/github/hydrogen-dev/smart-contracts/badge.svg?branch=master)](https://coveralls.io/github/hydrogen-dev/smart-contracts?branch=master)

## Introduction
Snowflake is an [ERC-1484 `Provider`](https://erc1484.org/) that provides on-/off-chain identity management. For more details, see [our whitepaper](https://github.com/hydrogen-dev/hydro-docs/tree/master/Snowflake).

##
[Try the demo front-end](https://hydroblockchain.github.io/snowflake-dashboard/)!

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

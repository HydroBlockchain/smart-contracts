# Hydro Token and Server-Side Raindrop
<img src="https://www.hydrogenplatform.com/images/logo_hydro.png">

## Introduction
[Project Hydro](http://www.projecthydro.com) is developing blockchain software powered by the Hydro token (HYDRO). Our token conforms to the [ERC-20 Ethereum token standard](https://theethereum.wiki/w/index.php/ERC20_Token_Standard).

Enterprise Raindrop is integrated directly into the token, and works alongside systems like [OAuth](https://en.wikipedia.org/wiki/OAuth) and [JWT](https://en.wikipedia.org/wiki/JSON_Web_Token) to secure APIs, databases, and other large access-controlled private systems.

## Contract Addresses
[Hydro Token Contract](https://etherscan.io/token/0xebbdf302c940c6bfd49c6b165f457fdb324649bc)

[Raindrop Enterprise](https://etherscan.io/address/0xe68225eeaeae795bbfa3cebd1dfe422e1b17ce55)

## Documentation
Project Hydro has also created an API to interface with this smart contract:

[Hydro API Documentation](https://www.hydrogenplatform.com/docs/hydro/v1/)

## Testing With Truffle
- This folder has a suite of tests created through [Truffle](https://github.com/trufflesuite/truffle)
- To run these test:
  - Clone this repo: `git clone https://github.com/hydrogen-dev/smart-contracts.git`
  - Navigate to the `hydro-token-and-server-raindrop` folder in your terminal
  - Make sure you have the appropriate Truffle version installed: `npm install -g truffle@4.1.3`
  - Install web3: `npm install web3@1.0.0-beta.34`
  - `truffle test`


## Copyright & License
Copyright 2018 The Hydrogen Technology Corporation under the GNU General Public License v3.0.

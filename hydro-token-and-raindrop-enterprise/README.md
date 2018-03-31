# Hydro Token and Enterprise Raindrop
<img src="https://www.hydrogenplatform.com/images/logo_hydro.png">

## Introduction
The Hydro Smart Contract is open source blockchain software developed by [Project Hydro](http://www.projecthydro.com).

[Hydro Token Contract Address](https://etherscan.io/token/0xebbdf302c940c6bfd49c6b165f457fdb324649bc)

ERC-20 tokens are an Ethereum standard. More information can be found [here](https://theethereum.wiki/w/index.php/ERC20_Token_Standard).

Our enterprise raindrop logic is created to work alongside systems like [OAuth](https://en.wikipedia.org/wiki/OAuth) and [JWT](https://en.wikipedia.org/wiki/JSON_Web_Token). It can be used to secure APIs and Databases.

## Documentation
Project Hydro has also created an API to interface with this smart contract:

[Hydro API Documentation](https://www.hydrogenplatform.com/docs/hydro/v1/)

## Testing With Truffle
- This folder has a suite of tests created through [Truffle](https://github.com/trufflesuite/truffle)
- To run these test:
  - Download the code: `git clone https://github.com/hydrogen-dev/smart-contracts.git`
  - Navigate to the `hydro-token-and-raindrop-enterprise` folder in your terminal
  - Make sure you have Truffle installed: `npm install -g truffle@4.1.3`
  - Install web3: `npm install web3@1.0.0-beta.33`
  - `$ truffle compile`
  - `$ truffle test`


## Copyright & License
Copyright 2018 The Hydrogen Technology Corporation under the GNU General Public License v3.0.

For the .env file, fill it out with the following:
```
ETHERSCAN_API_KEY={API_KEY}
MNEMONIC="12 random words of mnemonic"
INFURA_URL=https://rinkeby.infura.io/v3/{API_KEY}
ALCHEMY_URL=https://eth-rinkeby.alchemyapi.io/v2/{API_KEY}}

#CHAINLINK VRF Rinkeby
CHAINLINK_VRF_COORDINATOR=0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B
CHAINLINK_VRF_LINK_TOKEN=0x01BE23585060835E02B77ef475b0Cc51aA1e0709
CHAINLINK_VRF_KEY_HASH=0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311
CHAINLINK_VRF_FEE=100000000000000000

#CHAINLINK VRF Mainnet
#CHAINLINK_VRF_COORDINATOR=0xf0d54349aDdcf704F77AE15b96510dEA15cb7952
#CHAINLINK_VRF_LINK_TOKEN=0x514910771AF9Ca656af840dff83E8264EcF986CA
#CHAINLINK_VRF_KEY_HASH=0xAA77729D3466CA35AE8D28B3BBAC7CC36A5031EFDC430821C02BC31A238AF445
#CHAINLINK_VRF_FEE=2000000000000000000
```
Please use .env-example as a template.

Please read notes.md for temporary changes to the contracts. Also have a look at slither.md file for security vulnerabilities found during the slither scan.

If you have problems deploying the contracts via ganache-cli, please use the following command:
```
ganache-cli --gasLimit=0x1fffffffffffff 
```

For deploying to mainnet, update package.json file script for "migrate" from "rinkeby" to correct variable for mainnet. Will need to update `truffle-config.js` accordingly as well.
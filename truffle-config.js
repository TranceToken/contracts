const HDWalletProvider = require('@truffle/hdwallet-provider')
const dotenv = require("dotenv")

dotenv.config()
const infuraKey = process.env.INFURA_KEY || 'e272d9d07a2e489d94cee678fede6768'
const infuraSecret = process.env.INFURA_SECRET || 'f8090e1cab234582b5d3ae115ee9edef'
const liveNetworkPK = process.env.LIVE_PK || '74d5a39be460e487ce7ff9b0e27ab444190697da3851455d22fd61e869aaa75f'
const privKeysRinkeby = [ liveNetworkPK ]
const etherscanApiKey = process.env.ETHERS_SCAN_API_KEY || 'IEZC4N53PVJD9TVHV2KZDSVVKRM5D46PJZ'
const polygonApiKey = process.env.POLYGON_SCAN_API_KEY || ''
const bscApiKey = process.env.BSC_SCAN_API_KEY || ''

module.exports = {
  networks: {
    ganache: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "222222222",
      websocket: true
    },
    rinkeby: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        //providerOrUrl: `https://:${infuraSecret}@rinkeby.infura.io/v3/${infuraKey}`,
        providerOrUrl: `wss://:${infuraSecret}@rinkeby.infura.io/ws/v3/${infuraKey}`,
        pollingInterval: 56000
      }),
      network_id: 4,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
    },
    goerli: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        //providerOrUrl: `https://:${infuraSecret}@goerli.infura.io/v3/${infuraKey}`,
        providerOrUrl: `wss://:${infuraSecret}@goerli.infura.io/ws/v3/${infuraKey}`,
        pollingInterval: 56000
      }),
      network_id: 5,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: '0x10e9Cb334ac84b109176C42b6F0d05BDc2EC5C85',
      networkCheckTimeout: 999999
    },
    bsc_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://data-seed-prebsc-1-s1.binance.org:8545`,
        pollingInterval: 56000
      }),
      network_id: 97,
      confirmations: 2,
      timeoutBlocks: 100,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      skipDryRun: true,
      networkCheckTimeout: 999999
    },
    pulsechain_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://rpc.v2b.testnet.pulsechain.com`,
        pollingInterval: 56000
      }),
      network_id: 941,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
    },
    ethw_testnet: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://iceberg.ethereumpow.org/`,
        pollingInterval: 56000
      }),
      network_id: 10002,
      confirmations: 2,
      timeoutBlocks: 100,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
    },
    mumbai: {
      provider: () => new HDWalletProvider({
        privateKeys: privKeysRinkeby,
        providerOrUrl: `https://rpc-mumbai.maticvigil.com/v1/53a113316e0a9e20bcf02b13dd504ac33aeea3ba`,
        pollingInterval: 56000
      }),
      network_id: 80001,
      confirmations: 2,
      timeoutBlocks: 200,
      pollingInterval: 1000,
      skipDryRun: true,
      from: '0x6B889Dcfad1a6ddf7dE3bC9417F5F51128efc964',
      networkCheckTimeout: 999999
      //websockets: true
    },
  },
  mocha: {
    timeout: 100_000
  },
  compilers: {
    solc: {
      version: "0.8.10",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
        evmVersion: "london"
      }
    }
  },
  db: {
    enabled: false
  },
  plugins: ['truffle-plugin-verify'],
  api_keys: {
    etherscan: etherscanApiKey,
    bscscan: bscApiKey,
    polygonscan: polygonApiKey
  }
};

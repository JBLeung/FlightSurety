const mnemonic = 'candy maple cake sugar pudding cream honey rich smooth crumble sweet treat'

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*',
      gas: 9999999999999,
      gasPrice: 1,
      accounts: 50,
      defaultEtherBalance: 1000,
      websockets: true,
      mnemonic,
    },
  },
  compilers: {
    solc: {
      version: '^0.4.25',
    },
  },
}

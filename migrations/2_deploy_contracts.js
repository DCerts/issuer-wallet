const MultiSigWallet = artifacts.require('MultiSigWallet');
const fs = require('fs');

module.exports = function (deployer) {
    const config = JSON.parse(fs.readFileSync('config.json'));
    deployer.deploy(MultiSigWallet, config.name, config.members, config.threshold, config.address);
};
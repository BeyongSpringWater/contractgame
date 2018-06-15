var Party = artifacts.require("./Party.sol");

module.exports = function(deployer) {
  deployer.deploy(Party, "郭化权主办的会议", 20, 100, 20);
};

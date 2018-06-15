var PartyProxy = artifacts.require("./PartyProxy.sol");

module.exports = function(deployer) {
    deployer.deploy(PartyProxy,0x610b8ac0e5dab84721b89812eaff1b4157d50542,"0xc6b32f34");//apply(address)

    //deployer.deploy(PartyProxy,0x610b8ac0e5dab84721b89812eaff1b4157d50542,"0x1dd8c3d0");//getReturnBonus(address)
};

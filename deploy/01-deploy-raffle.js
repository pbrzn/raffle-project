const ENTRANCE_FEE = ethers.utils.parse("0.1");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = wait getNamedAccounts();

  const args = [
    ENTRANCE_FEE,
    "300", //interval
    "0x271682DEB8C4E0901D1a1550aD2e64D568E69909", //vrf coordinator
    "0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef", //gas lane
    "1002", //subscription id from chainlink
    "500000" // callback gas limit
  ];

  const raffle = await deploy("Raffle", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: 6,
  })
}

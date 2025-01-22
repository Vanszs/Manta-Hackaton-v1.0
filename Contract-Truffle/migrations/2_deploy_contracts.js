const SubscriptionWithAdmin = artifacts.require("SubscriptionWithAdmin");

module.exports = async function (deployer) {
  await deployer.deploy(SubscriptionWithAdmin);
};

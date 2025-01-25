const SubscriptionDAO = artifacts.require("SubscriptionDAO");

module.exports = function (deployer) {
    deployer.deploy(SubscriptionDAO);
};

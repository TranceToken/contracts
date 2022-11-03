const XENCrypto = artifacts.require("XENCrypto");
const Math = artifacts.require("Math");

module.exports = async function (deployer) {
  await deployer.deploy(Math);
  await deployer.link(Math, XENCrypto);
  await deployer.deploy(XENCrypto, '0xa46dfc771a8603223e8ce30bebb78fe6c3e743fb693e5dcf06cf83c7b4b07c00');
};

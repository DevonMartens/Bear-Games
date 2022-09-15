const HONEY = artifacts.require("HONEY");
const Forest = artifacts.require("Forest");
const Bear = artifacts.require("Bear");
const Traits = artifacts.require("Traits");
// const Executor = artifacts.require("Executor");
const comboTraits = require("../CombinedTraits.json");
const { CHAINLINK_VRF_COORDINATOR, CHAINLINK_VRF_LINK_TOKEN, CHAINLINK_VRF_KEY_HASH, CHAINLINK_VRF_FEE } = process.env;

module.exports = async function (deployer) {

	await deployer.deploy(HONEY);
	const honey = await HONEY.deployed();
	await deployer.deploy(Traits);

	await deployer.deploy(Bear, honey.address, Traits.address, 50000, CHAINLINK_VRF_COORDINATOR, CHAINLINK_VRF_LINK_TOKEN, CHAINLINK_VRF_KEY_HASH, CHAINLINK_VRF_FEE);
	const beear = await Bear.deployed();
	await deployer.deploy(Forest, beear.address, honey.address);
	const forest = await Forest.deployed();

	// await deployer.deploy(Executor, beear.address, forest.address);
	// Executor is a exploit smart contract to hack into the game - should not be deployed in production

	await beear.setForest(forest.address);
	const traits = await Traits.deployed();
	await traits.setBeear(beear.address);

	// await Promise.all(
	// 	[...new Array(17)].map(async (_, i) => {
	// 		const ids = [...new Array(28)].map((_, i) => [i]);
	// 		const ts = [...new Array(28)].map((_, i) => ({
	// 			name: "None" + i,
	// 			png: "1",
	// 		}));
	// 		await traits.uploadTraits(i + 1, ids, ts);
	// 	})
	// );
  
	for (let i = 0; i < comboTraits.length; i++) {
		let ids = [];
		let ts = [];
		let name;
		let png;

		for (let j = 0; j < comboTraits[i][2].length; j++) {
			name = comboTraits[i][2][j][0];
			png = comboTraits[i][2][j][1];

			ts.push([name, png]);
			ids = [...Array(comboTraits[i][2].length).keys()];
		}
		await traits.uploadTraits(i, ids, ts);
	}
	await honey.addController(forest.address);
};

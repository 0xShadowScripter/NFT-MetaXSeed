const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MetaXSeed Contract", function () {
  let MetaXSeed;
  let metaXSeed;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    MetaXSeed = await ethers.getContractFactory("MetaXSeed");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    metaXSeed = await MetaXSeed.deploy("MetaXSeed Token", "MTX", owner.address, 1000);
  });

  describe("Global and Individual Transferability", function () {
    it("Should prevent transfer if global and individual transferability are false", async function () {
      await metaXSeed.safeMint(owner.address, 1, "uri://token1", false);
      await expect(metaXSeed.connect(owner).transferFrom(owner.address, addr1.address, 1))
        .to.be.revertedWith("Token is not transferable");
    });

    it("Should allow transfer if global transferability is true", async function () {
      await metaXSeed.setGlobalTransferability(true);
      await metaXSeed.safeMint(owner.address, 1, "uri://token2", false);
      await expect(metaXSeed.connect(owner).transferFrom(owner.address, addr1.address, 1))
        .not.to.be.reverted;
    });

    it("Should allow transfer if individual token transferability is true even if global is false", async function () {
      await metaXSeed.setGlobalTransferability(false);
      await metaXSeed.safeMint(owner.address, 3, "uri://token3", true);
      await expect(metaXSeed.connect(owner).transferFrom(owner.address, addr1.address, 3))
        .not.to.be.reverted;
    });
  });

  describe("Setting Transferability Range", function () {
    beforeEach(async function () {
      // Mint tokens with default transferability to false
      for (let i = 4; i <= 6; i++) {
        await metaXSeed.safeMint(owner.address, i, `uri://token${i}`, false);
      }
    });

    it("Should set transferability for a range of tokens", async function () {
      await metaXSeed.setTokenTransferabilityRange(4, 6, true);
      for (let i = 4; i <= 6; i++) {
        await expect(metaXSeed.connect(owner).transferFrom(owner.address, addr1.address, i))
          .not.to.be.reverted;
      }
    });
  });
});

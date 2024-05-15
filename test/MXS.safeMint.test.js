const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MetaXSeed Contract", function () {
    let MetaXSeed, metaXSeed, owner, addr1, addr2;

    beforeEach(async function () {
        MetaXSeed = await ethers.getContractFactory("MetaXSeed");
        [owner, addr1, addr2] = await ethers.getSigners();
        // Deploy with a max supply of 10 for testing
        metaXSeed = await MetaXSeed.deploy("MetaXSeed", "MTX", owner.address, 10);
    });

    describe("Ownership and Access Control Tests", function() {

        it("should allow owner to add a new signer", async function () {
            await metaXSeed.addSigner(addr1.address);
            expect(await metaXSeed.signers(addr1.address)).to.be.true;
        });

        it("should allow owner to remove a signer", async function () {
            await metaXSeed.addSigner(addr1.address);
            await metaXSeed.removeSigner(addr1.address);
            expect(await metaXSeed.signers(addr1.address)).to.be.false;
        });

        it("should prevent non-owners from adding signers", async function () {
            await expect(metaXSeed.connect(addr1).addSigner(addr2.address)).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("should prevent non-owners from removing signers", async function () {
            await expect(metaXSeed.connect(addr1).removeSigner(addr1.address)).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Minting Functionality Tests", function() {
        it("should mint a token", async function () {
            await metaXSeed.safeMint(addr1.address, 1, "tokenURI1", true);
            expect(await metaXSeed.ownerOf(1)).to.equal(addr1.address);
            expect(await metaXSeed.transferableTokens(1)).to.be.true;
        });

        it("should batch mint tokens", async function () {
            const tokenIds = [1, 2];
            const tokenURIs = ["uri1", "uri2"];
            const transferables = [true, false];
            await metaXSeed.safeMintBatch(addr1.address, tokenIds, tokenURIs, transferables);
            expect(await metaXSeed.ownerOf(1)).to.equal(addr1.address);
            expect(await metaXSeed.ownerOf(2)).to.equal(addr1.address);
            expect(await metaXSeed.transferableTokens(1)).to.be.true;
            expect(await metaXSeed.transferableTokens(2)).to.be.false;
        });

        it("should fail to mint beyond max supply", async function () {
            for (let i = 1; i <= 10; i++) {
                await metaXSeed.safeMint(addr1.address, i, `uri${i}`, true);
            }
            await expect(metaXSeed.safeMint(addr1.address, 12, "uri11", true)).to.be.revertedWith("Max supply reached");
        });

        it("should fail to batch mint beyond max supply", async function () {
            for (let i = 1; i <= 9; i++) {
                await metaXSeed.safeMint(addr1.address, i, `uri${i}`, true);
            }
            const tokenIds = [11, 12]; // Attempting to mint three more should fail
            const tokenURIs = ["uri9", "uri9"];
            const transferables = [true, true];
            const supply = await metaXSeed.totalSupply();
            await expect(metaXSeed.safeMintBatch(addr1.address, tokenIds, tokenURIs, transferables)).to.be.revertedWith("Batch mint would exceed max supply");

        });
        it("should allow the owner to update the token URI", async function () {
          const tokenId = 1;
          const initialURI = "https://example.com/original";
          const newURI = "https://example.com/updated";
  
          await metaXSeed.safeMint(owner.address, tokenId, initialURI, true);
          expect(await metaXSeed.tokenURI(tokenId)).to.equal(initialURI);
  
          await metaXSeed.setTokenURI(tokenId, newURI);
          expect(await metaXSeed.tokenURI(tokenId)).to.equal(newURI);
      });
  
      it("should prevent non-owners from updating the token URI", async function () {
          const tokenId = 1;
          const initialURI = "https://example.com/original";
          const newURI = "https://example.com/updated";
  
          await metaXSeed.safeMint(owner.address, tokenId, initialURI, true);
          await expect(metaXSeed.connect(addr1).setTokenURI(tokenId, newURI))
              .to.be.revertedWith("Ownable: caller is not the owner");
      });
    });
  });
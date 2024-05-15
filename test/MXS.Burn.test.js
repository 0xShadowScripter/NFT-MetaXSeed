const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MetaXSeed Contract - Burn Functionality", function () {
    let MetaXSeed, metaXSeed, owner, addr1;

    beforeEach(async function () {
        MetaXSeed = await ethers.getContractFactory("MetaXSeed");
        [owner, addr1] = await ethers.getSigners();
        metaXSeed = await MetaXSeed.deploy("MetaXSeed", "MTX", owner.address, 10);
    });

    it("should burn a token and decrement the token counter", async function () {
        // Mint a token first
        await metaXSeed.safeMint(owner.address, 1, "tokenURI1", true);
        expect(await metaXSeed.totalSupply()).to.equal(1);
    
        // Burn the token
        await metaXSeed.burn(1);
        expect(await metaXSeed.totalSupply()).to.equal(0);
    
        // Check that the token no longer exists
        await expect(metaXSeed.ownerOf(1)).to.be.revertedWith("ERC721: owner query for nonexistent token");
    });

    it("should prevent unauthorized users from burning a token", async function () {
        // Mint a token to the owner
        await metaXSeed.safeMint(owner.address, 1, "tokenURI1", true);

        // Attempt to burn the token from another address
        await expect(metaXSeed.connect(addr1).burn(1))
            .to.be.revertedWith("Caller is not owner nor approved");
    });
});

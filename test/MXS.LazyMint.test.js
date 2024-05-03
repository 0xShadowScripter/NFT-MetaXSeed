const { expect } = require('chai');
const { ethers } = require('hardhat');
const WEEK = 3600 * 24 * 7; // one week in seconds

describe("MetaXSeed Contract Tests", function () {
    let MetaXSeed, metaXSeed, owner, addr1, addr2, signer;

    before(async function () {
        MetaXSeed = await ethers.getContractFactory("MetaXSeed");
        [owner, addr1, addr2, signer] = await ethers.getSigners();
        metaXSeed = await MetaXSeed.deploy("MetaXSeed", "MTX", signer.address, owner.address, 10);
    });    

    describe("Lazy Minting", function () {
        it("should recognize an authorized signer", async function () {
            expect(await metaXSeed.signers(signer.address)).to.be.true;
        });
        
        it("should lazily mint a token with a valid signature", async function () {


            const tokenId = 1;
            const tokenURI = "https://example.com/token1";
            const salt = ethers.utils.randomBytes(32);
            const expiry = (await ethers.provider.getBlock('latest')).timestamp + 300; // valid for 5 minutes

            const data = {
                to: addr1.address,
                tokenId: tokenId,
                transferable: true,
                salt: ethers.utils.hexlify(salt),
                tokenURI: tokenURI,
                expiry: expiry
            };

            const signature = await generateSignature(signer, data, metaXSeed);
            await expect(metaXSeed.lazyMint(addr1.address, tokenId, true, salt, tokenURI, signature, expiry))
                .to.emit(metaXSeed, 'Transfer')
                .withArgs(ethers.constants.AddressZero, addr1.address, tokenId);

            const totalSupply = await metaXSeed.totalSupply();
            expect(totalSupply).to.equal(1);
        });

        it("should fail to lazily mint with an expired signature", async function () {
            const tokenId = 2;
            const tokenURI = "https://example.com/token2";
            const salt = ethers.utils.hexlify(ethers.utils.randomBytes(32));
            const expiry = (await ethers.provider.getBlock('latest')).timestamp + WEEK+10;// already expired

            const data = {
                to: addr1.address,
                tokenId: tokenId,
                transferable: true,
                salt: ethers.utils.hexlify(salt),
                tokenURI: tokenURI,
                expiry: expiry
            };

            const signature = await generateSignature(signer, data, metaXSeed);
            await expect(metaXSeed.lazyMint(addr1.address, tokenId, true, salt, tokenURI, signature, expiry))
                .to.be.revertedWith("Signature has expired");
        });
    });

    describe("Transferability and Total Supply", function () {
        it("should update transferability and check transfer fails when non-transferable", async function () {
            await metaXSeed.safeMint(3, addr1.address, "https://example.com/token3", true);
            await metaXSeed.setTokenTransferability(3, false);
            await expect(metaXSeed.connect(addr1).transferFrom(addr1.address, addr2.address, 3))
                .to.be.revertedWith("Token is not transferable");
        });

        it("should correctly report total supply", async function () {
            const initialSupply = await metaXSeed.totalSupply();
            await metaXSeed.safeMint(4, addr1.address,"https://example.com/token4", true);
            const finalSupply = await metaXSeed.totalSupply();
            console.log("initialSupply",initialSupply)
            console.log("finalSupply",finalSupply)
            expect(finalSupply.sub(initialSupply)).to.equal(1); // Here sub is a BigNumber method
        });        
    });
});

async function generateSignature(signer, data, contract) {
    return await signer._signTypedData(
        {
            name: "MetaXSeeds",
            version: "1",
            chainId: await signer.getChainId(),
        verifyingContract: contract.address
        },
        {
            LazyMint: [
                { name: "to", type: "address" },
                { name: "tokenId", type: "uint256" },
                { name: "transferable", type: "bool" },
                { name: "salt", type: "bytes32" },
                { name: "tokenURI", type: "string" },
                { name: "expiry", type: "uint256" }
            ]
        },
        data
    );
}



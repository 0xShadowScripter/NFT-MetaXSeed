const { expect } = require('chai');
const { ethers } = require('hardhat');

describe("Batch Lazy Minting", function () {

    let MetaXSeed, metaXSeed, owner, addr1, addr2, signer;

    before(async function () {
        MetaXSeed = await ethers.getContractFactory("MetaXSeed");
        [owner, addr1, addr2, signer] = await ethers.getSigners();
        metaXSeed = await MetaXSeed.deploy("MetaXSeed", "MTX", signer.address, 10);
    });
    it("should lazily mint 5 tokens with valid signatures using batchLazyMinting", async function () {
        const tokenId1 = 11;
        const tokenURI1 = "https://example.com/token1";
        const salt1 = ethers.utils.randomBytes(32);
        const expiry1 = (await ethers.provider.getBlock('latest')).timestamp + 300; // valid for 5 minutes
    
        const tokenId2 = 12;
        const tokenURI2 = "https://example.com/token2";
        const salt2 = ethers.utils.randomBytes(32);
        const expiry2 = (await ethers.provider.getBlock('latest')).timestamp + 300; // valid for 5 minutes
    
        const tokenId3 = 13;
        const tokenURI3 = "https://example.com/token3";
        const salt3 = ethers.utils.randomBytes(32);
        const expiry3 = (await ethers.provider.getBlock('latest')).timestamp + 300; // valid for 5 minutes
    
        const tokenId4 = 14;
        const tokenURI4 = "https://example.com/token4";
        const salt4 = ethers.utils.randomBytes(32);
        const expiry4 = (await ethers.provider.getBlock('latest')).timestamp + 300; // valid for 5 minutes
    
        const tokenId5 = 15;
        const tokenURI5 = "https://example.com/token5";
        const salt5 = ethers.utils.randomBytes(32);
        const expiry5 = (await ethers.provider.getBlock('latest')).timestamp + 300; // valid for 5 minutes
    
        const data1 = {
            to: addr1.address,
            tokenId: tokenId1,
            transferable: true,
            salt: ethers.utils.hexlify(salt1),
            tokenURI: tokenURI1,
            expiry: expiry1
        };
        const data2 = {
            to: addr1.address,
            tokenId: tokenId2,
            transferable: true,
            salt: ethers.utils.hexlify(salt2),
            tokenURI: tokenURI2,
            expiry: expiry2
        };
        const data3 = {
            to: addr1.address,
            tokenId: tokenId3,
            transferable: true,
            salt: ethers.utils.hexlify(salt3),
            tokenURI: tokenURI3,
            expiry: expiry3
        };
        const data4 = {
            to: addr1.address,
            tokenId: tokenId4,
            transferable: true,
            salt: ethers.utils.hexlify(salt4),
            tokenURI: tokenURI4,
            expiry: expiry4
        };
        const data5 = {
            to: addr1.address,
            tokenId: tokenId5,
            transferable: true,
            salt: ethers.utils.hexlify(salt5),
            tokenURI: tokenURI5,
            expiry: expiry5
        };
    
        const signature1 = await generateSignature(signer, data1, metaXSeed);
        const signature2 = await generateSignature(signer, data2, metaXSeed);
        const signature3 = await generateSignature(signer, data3, metaXSeed);
        const signature4 = await generateSignature(signer, data4, metaXSeed);
        const signature5 = await generateSignature(signer, data5, metaXSeed);
        console.log("salt1", salt1)
        console.log("salt2", salt2)
        
        console.log("signature1", signature1)
        console.log("signature2", signature2)

    
        await metaXSeed.batchLazyMint(
            addr1.address,
            [tokenId1, tokenId2, tokenId3, tokenId4, tokenId5],
            [true, true, true, true, true], // matching transferable status with the data
            [salt1, salt2, salt3, salt4, salt5],
            [tokenURI1, tokenURI2, tokenURI3, tokenURI4, tokenURI5],
            [signature1, signature2, signature3, signature4, signature5],
            [expiry1, expiry2, expiry3, expiry4, expiry5]
        );
    
        const totalSupply = await metaXSeed.totalSupply();

        console.log(totalSupply)
        expect(totalSupply).to.equal(5); // Expect the total supply to be 5 after minting
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
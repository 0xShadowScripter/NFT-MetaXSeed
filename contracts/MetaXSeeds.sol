// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title A contract for minting unique digital assets on the Ethereum blockchain
/// @dev Extends ERC721URIStorage for token URI storage capabilities
contract MetaXSeed is ERC721URIStorage, EIP712, Ownable {
    // Use library `Counters` for safe counter operations
    using Counters for Counters.Counter;
    // Use library `ECDSA` for operations on `bytes32` related to ECDSA signatures
    using ECDSA for bytes32;

    /// @dev Counter for tracking token IDs
    Counters.Counter private tokenIdCounter;

    /// @notice Address where collected fees are sent
    address public feeCollector;

    /// @notice Maximum number of tokens that can be minted
    uint256 public maxSupply;

    /// @notice Mapping from token ID to its transferability status
    mapping(uint256 => bool) public transferableTokens;

    /// @notice Mapping to track used salts to prevent replay attacks
    mapping(bytes32 => bool) public usedSalts;

    /// @notice Mapping of addresses authorized to sign token minting requests
    mapping(address => bool) public signers;

    /// @dev Constant for a week's worth of seconds (used for time calculations)
    uint32 private constant WEEK = 3600 * 24 * 7;

    /// @dev Domain name used for EIP-712 typed data signing
    string private constant SIGNING_DOMAIN = "MetaXSeeds";

    /// @dev Version of the EIP-712 domain
    string private constant SIGNATURE_VERSION = "1";

    /// @dev Hash of the type for the EIP-712 typed data signature for lazy minting
    bytes32 private constant LAZY_MINT_TYPEHASH =
        keccak256(
            "LazyMint(address to,uint256 tokenId,bool transferable,bytes32 salt,string tokenURI,uint256 expiry)"
        );

    /// @notice Constructor to create MetaXSeed
    /// @param name Name of the token
    /// @param symbol Symbol of the token
    /// @param signerAddress Initial address that is authorized to sign minting requests
    /// @param feeCollectorAddress Address where minting fees will be sent
    /// @param _maxSupply Initial maximum supply of tokens
    constructor(
        string memory name,
        string memory symbol,
        address signerAddress,
        address feeCollectorAddress,
        uint256 _maxSupply
    ) ERC721(name, symbol) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        signers[signerAddress] = true;
        feeCollector = feeCollectorAddress;
        maxSupply = _maxSupply; // Set the maximum supply
    }

    /// @notice Adds a new signer for the token minting
    /// @dev This function can only be called by the contract owner
    /// @param _signer Address of the new signer
    function addSigner(address _signer) public onlyOwner {
        require(_signer != address(0), "Bad signer");
        signers[_signer] = true;
    }

    /// @notice Removes a signer from the list of authorized signers
    /// @dev This function can only be called by the contract owner
    /// @param _signer The address of the signer to remove
    function removeSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Bad signer");
        delete signers[_signer];
    }

    /// @notice Mints a new token with specific properties
    /// @dev This function can only be called by the contract owner
    /// @param tokenId The token ID to mint
    /// @param to The recipient of the token
    /// @param tokenURI The URI for the token metadata
    /// @param transferable Whether the token is transferable
    function safeMint(
        uint256 tokenId,
        address to,
        string memory tokenURI,
        bool transferable
    ) public onlyOwner {
        require(tokenIdCounter.current() < maxSupply, "Max supply reached");
        tokenIdCounter.increment();
        transferableTokens[tokenId] = transferable;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
    }

    /// @notice Mints multiple tokens in a batch with specific properties and unique token IDs
    /// @dev This function can only be called by the contract owner
    /// @param to The recipient of the tokens
    /// @param tokenIds An array of token IDs for the tokens to mint
    /// @param tokenURIs An array of URIs for the token metadata
    /// @param transferables An array indicating whether each token is transferable
    function safeMintBatch(
        address to,
        uint256[] memory tokenIds,
        string[] memory tokenURIs,
        bool[] memory transferables
    ) public onlyOwner {
        require(
            tokenIds.length == tokenURIs.length &&
                tokenURIs.length == transferables.length,
            "Array lengths must match"
        );

        // Ensure minting this batch won't exceed the max supply
        require(
            tokenIdCounter.current() + tokenIds.length < maxSupply,
            "Batch mint would exceed max supply"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(!_exists(tokenIds[i]), "Token ID already exists");
            transferableTokens[tokenIds[i]] = transferables[i];
            _safeMint(to, tokenIds[i]);
            _setTokenURI(tokenIds[i], tokenURIs[i]);
            // Manually increment the tokenIdCounter after each mint
            tokenIdCounter.increment();
        }
    }

    /// @notice Lazily mints a token after verifying the signature
    /// @param to The recipient of the token
    /// @param tokenId The ID of the token to mint
    /// @param transferable Indicates whether the token is transferable
    /// @param salt A unique salt to prevent replay attacks
    /// @param tokenURI The URI for the token metadata
    /// @param signature The signature to verify
    /// @param expiry The timestamp after which the signature expires
    function lazyMint(
        address to,
        uint256 tokenId,
        bool transferable,
        bytes32 salt,
        string memory tokenURI,
        bytes memory signature,
        uint256 expiry
    ) public {
        require(tokenIdCounter.current() < maxSupply, "Max supply reached");
        require(expiry <= block.timestamp + WEEK, "Signature has expired");
        require(!usedSalts[salt], "Salt has already been used");
        usedSalts[salt] = true;

        bytes32 structHash = keccak256(
            abi.encode(
                LAZY_MINT_TYPEHASH,
                to,
                tokenId,
                transferable,
                salt,
                keccak256(bytes(tokenURI)),
                expiry
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, signature);

        require(signer != address(0), "Invalid signature");
        require(signers[signer], "Invalid signer");

        tokenIdCounter.increment();
        transferableTokens[tokenId] = transferable;
        _safeMint(to, tokenId); // mint to the specified 'to' address
        _setTokenURI(tokenId, tokenURI);
    }

    /// @notice Burns a token and decrements the token counter
    /// @param tokenId The ID of the token to burn
    function burn(uint256 tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Caller is not owner nor approved"
        );
        _burn(tokenId);

        // Decrement the token counter if the token exists and has been successfully burned
        if (tokenIdCounter.current() > 0) {
            tokenIdCounter.decrement();
        }

        // Optionally, clean up any data related to the token
        delete transferableTokens[tokenId];
        // Note: `_burn` will also clean up the owner and approval mappings in ERC721
    }

    /// @notice Sets the transferability status of a specific token
    /// @dev Only callable by the owner of the contract
    /// @param tokenId The ID of the token to update
    /// @param transferable Boolean indicating whether the token can be transferred
    function setTokenTransferability(uint256 tokenId, bool transferable)
        public
        onlyOwner
    {
        require(_exists(tokenId), "Token does not exist");
        transferableTokens[tokenId] = transferable;
    }

    /// @notice Retrieves the current total supply of tokens
    /// @return The total number of tokens minted so far
    function totalSupply() public view returns (uint256) {
        return tokenIdCounter.current();
    }

    /// @dev Overrides the ERC721 _transfer method to include a check for token transferability
    /// @param from The address to transfer the token from
    /// @param to The address to transfer the token to
    /// @param tokenId The ID of the token to transfer
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(transferableTokens[tokenId], "Token is not transferable");
        super._transfer(from, to, tokenId);
    }

    /// @notice Verifies the signature of a minting request for migration purposes
    /// @dev This function does not change state but returns the signer of a valid signature
    /// @param to The intended recipient of the token to be minted
    /// @param tokenId The ID of the token to be minted
    /// @param transferable Indicates whether the token will be transferable
    /// @param salt A nonce to ensure signatures cannot be reused
    /// @param tokenURI The URI for the token's metadata
    /// @param signature The cryptographic signature to be verified
    /// @param expiry The timestamp at which the signature expires
    /// @return digest The hash of the minting data
    /// @return signer The address that signed the minting data
    function verifyMigrationSignature(
        address to,
        uint256 tokenId,
        bool transferable,
        bytes32 salt,
        string memory tokenURI,
        bytes memory signature,
        uint256 expiry
    ) external view returns (bytes32 digest, address signer) {
        bytes32 structHash = keccak256(
            abi.encode(
                LAZY_MINT_TYPEHASH,
                to,
                tokenId,
                transferable,
                salt,
                keccak256(bytes(tokenURI)),
                expiry
            )
        );
        digest = _hashTypedDataV4(structHash);
        signer = digest.recover(signature);

        return (digest, signer);
    }
}

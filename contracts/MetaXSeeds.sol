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
    //global token transferability
    bool public globalTransferable;

    // Use library `Counters` for safe counter operations
    using Counters for Counters.Counter;
    // Use library `ECDSA` for operations on `bytes32` related to ECDSA signatures
    using ECDSA for bytes32;

    /// @dev Counter for tracking token IDs
    Counters.Counter private tokenIdCounter;

    /// @notice Maximum number of tokens that can be minted
    uint256 public maxSupply;

    // Event for minting a new token
    event TokenMinted(
        address indexed owner,
        uint256 indexed tokenId,
        string tokenURI,
        bool transferable
    );

    // Event for adding a new signer
    event SignerAdded(address indexed signer);

    // Event for removing a signer
    event SignerRemoved(address indexed signer);

    // Event for lazy minting
    event LazyMinted(
        address indexed to,
        uint256 indexed tokenId,
        bool transferable,
        bytes32 salt,
        string tokenURI,
        bytes signature,
        uint256 expiry
    );

    // Event for burning a token
    event TokenBurned(address indexed owner, uint256 indexed tokenId);

    // Event for updating token URI
    event TokenURIUpdated(uint256 indexed tokenId, string newTokenURI);

    // Event for updating token transferability
    event TokenTransferabilityUpdated(
        uint256 indexed tokenId,
        bool transferable
    );

    // Event for batch Lazy minting
    event BatchLazyMinted(
        address indexed to,
        uint256[] tokenIds,
        string[] tokenURIs,
        bool[] transferables,
        bytes32[] salts,
        bytes[] signatures,
        uint256[] expiries
    );

    // Event for batch minting
    event BatchMinted(
        address indexed to,
        uint256[] tokenIds,
        string[] tokenURIs,
        bool[] transferables
    );

    /// @dev Version of the EIP-712 domain
    string private constant SIGNATURE_VERSION = "1";

    /// @dev Domain name used for EIP-712 typed data signing
    string private constant SIGNING_DOMAIN = "MetaXSeeds";

    /// @dev Hash of the type for the EIP-712 typed data signature for lazy minting
    bytes32 private constant LAZY_MINT_TYPEHASH =
        keccak256(
            "LazyMint(address to,uint256 tokenId,bool transferable,bytes32 salt,string tokenURI,uint256 expiry)"
        );
    /// @notice Mapping from token ID to its transferability status
    mapping(uint256 => bool) public transferableTokens;

    /// @notice Mapping to track used salts to prevent replay attacks
    mapping(bytes32 => bool) public usedSalts;

    /// @notice Mapping of addresses authorized to sign token minting requests
    mapping(address => bool) public signers;

    /// @dev Constant for a week's worth of seconds (used for time calculations)
    uint32 private constant WEEK = 3600 * 24 * 7;

    /// @dev to get owned Token Indexes
    mapping(uint256 => uint256) private _ownedTokensIndex;

    /// @dev to get owned Token
    mapping(address => uint256[]) private _ownedTokens;

    /// @notice Constructor to create MetaXSeed
    /// @param name Name of the token
    /// @param symbol Symbol of the token
    /// @param signerAddress Initial address that is authorized to sign minting requests
    /// @param _maxSupply Initial maximum supply of tokens
    constructor(
        string memory name,
        string memory symbol,
        address signerAddress,
        uint256 _maxSupply
    ) ERC721(name, symbol) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        signers[signerAddress] = true;
        maxSupply = _maxSupply; // Set the maximum supply
    }

    /// @notice Adds a new signer for the token minting
    /// @dev This function can only be called by the contract owner
    /// @param _signer Address of the new signer
    function addSigner(address _signer) public onlyOwner {
        require(_signer != address(0), "Bad signer");
        signers[_signer] = true;
        emit SignerAdded(_signer);
    }

    /// @notice Removes a signer from the list of authorized signers
    /// @dev This function can only be called by the contract owner
    /// @param _signer The address of the signer to remove
    function removeSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Bad signer");
        delete signers[_signer];
        emit SignerRemoved(_signer);
    }

    /// @notice Sets the global transferability for all tokens
    /// @dev Only callable by the owner of the contract
    /// @param _globalTransferable Boolean indicating the global transferability status
    function setGlobalTransferability(bool _globalTransferable)
        public
        onlyOwner
    {
        globalTransferable = _globalTransferable;
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
        require(!_exists(tokenId), "Token ID already exists");
        require(tokenIdCounter.current() <= maxSupply, "Max supply reached");
        tokenIdCounter.increment();
        transferableTokens[tokenId] = transferable;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        _addTokenToOwnerEnumeration(to, tokenId);
        emit TokenMinted(to, tokenId, tokenURI, transferable);
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
            tokenIdCounter.current() + tokenIds.length <= maxSupply,
            "Batch mint would exceed max supply"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(!_exists(tokenIds[i]), "Token ID already exists");
            transferableTokens[tokenIds[i]] = transferables[i];
            _safeMint(to, tokenIds[i]);
            _setTokenURI(tokenIds[i], tokenURIs[i]);
            _addTokenToOwnerEnumeration(to, tokenIds[i]);
            // Manually increment the tokenIdCounter after each mint
            tokenIdCounter.increment();
        }

        emit BatchMinted(to, tokenIds, tokenURIs, transferables);
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
        require(!_exists(tokenId), "Token ID already exists");
        require(tokenIdCounter.current() <= maxSupply, "Max supply reached");
        require(expiry <= block.timestamp + WEEK, "Signature has expired");
        require(!usedSalts[salt], "Salt has already been used");

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
        usedSalts[salt] = true;

        tokenIdCounter.increment();
        transferableTokens[tokenId] = transferable;
        _safeMint(to, tokenId); // mint to the specified 'to' address
        _setTokenURI(tokenId, tokenURI);
        _addTokenToOwnerEnumeration(to, tokenId);

        emit LazyMinted(
            to,
            tokenId,
            transferable,
            salt,
            tokenURI,
            signature,
            expiry
        );
    }

    /// @notice Lazily mints multiple tokens after verifying the signatures for each token
    /// @param to The recipient of the tokens
    /// @param tokenIds An array of token IDs to mint
    /// @param transferables An array indicating whether each token is transferable
    /// @param salts An array of unique salts to prevent replay attacks
    /// @param tokenURIs An array of URIs for the token metadata
    /// @param signatures An array of signatures to verify
    /// @param expiries An array of timestamps after which each signature expires
    function batchLazyMint(
        address to,
        uint256[] memory tokenIds,
        bool[] memory transferables,
        bytes32[] memory salts,
        string[] memory tokenURIs,
        bytes[] memory signatures,
        uint256[] memory expiries
    ) public onlyOwner {
        require(
            tokenIds.length == transferables.length &&
                transferables.length == salts.length &&
                salts.length == tokenURIs.length &&
                tokenURIs.length == signatures.length &&
                signatures.length == expiries.length,
            "Array lengths must match"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(!_exists(tokenIds[i]), "Token ID already exists");

            lazyMint(
                to,
                tokenIds[i],
                transferables[i],
                salts[i],
                tokenURIs[i],
                signatures[i],
                expiries[i]
            );
        }

        emit BatchLazyMinted(
            to,
            tokenIds,
            tokenURIs,
            transferables,
            salts,
            signatures,
            expiries
        );
    }

    /// @notice Burns a token and decrements the token counter
    /// @param tokenId The ID of the token to burn
    function burn(uint256 tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Caller is not owner nor approved"
        );

        address owner = ownerOf(tokenId);

        // Correctly remove the token
        _burn(tokenId);

        // Decrement the token counter if it's necessary for your logic (not standard in ERC721)
        // This assumes you want to keep track of the "active" supply, not just total minted ever
        if (tokenIdCounter.current() > 0) {
            tokenIdCounter.decrement();
        }

        // Clean up any additional data related to the token
        delete transferableTokens[tokenId];

        // Remove from owner enumeration
        _removeTokenFromOwnerEnumeration(owner, tokenId);

        emit TokenBurned(owner, tokenId);
    }

    /// @notice Sets or updates the URI for a given token
    /// @dev This function can only be called by the contract owner
    /// @param tokenId The token ID for which to set the URI
    /// @param newTokenURI The new URI to set for the token
    function setTokenURI(uint256 tokenId, string memory newTokenURI)
        public
        onlyOwner
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI set of nonexistent token"
        );
        _setTokenURI(tokenId, newTokenURI);

        emit TokenURIUpdated(tokenId, newTokenURI);
    }

    /// @notice Sets the transferability status for a range of tokens
    /// @dev Only callable by the owner of the contract
    /// @param startTokenId The starting ID of the token range to update
    /// @param endTokenId The ending ID of the token range to update
    /// @param transferable Boolean indicating whether the tokens in the range can be transferred
    function setTokenTransferabilityRange(
        uint256 startTokenId,
        uint256 endTokenId,
        bool transferable
    ) public onlyOwner {
        require(startTokenId <= endTokenId, "Invalid token ID range");
        for (uint256 tokenId = startTokenId; tokenId <= endTokenId; tokenId++) {
            require(_exists(tokenId), "Token does not exist");
            transferableTokens[tokenId] = transferable;
            emit TokenTransferabilityUpdated(tokenId, transferable);
        }
    }

    /// @notice Sets the transferability status for multiple tokens
    /// @dev Only callable by the owner of the contract
    /// @param tokenIds An array of token IDs to update
    /// @param transferable Boolean indicating whether the tokens can be transferred
    function setTokenTransferabilities(
        uint256[] calldata tokenIds,
        bool transferable
    ) public onlyOwner {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(_exists(tokenIds[i]), "Token does not exist");
            transferableTokens[tokenIds[i]] = transferable;
            emit TokenTransferabilityUpdated(tokenIds[i], transferable);
        }
    }

    /// @notice Retrieves the current total supply of tokens
    /// @return The total number of tokens minted so far
    function totalSupply() public view returns (uint256) {
        return tokenIdCounter.current();
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

    /// @notice Gets the list of token IDs owned by a given address
    /// @param owner The owner whose tokens we are interested in
    /// @return A list of token IDs owned by the address
    function tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        return _ownedTokens[owner];
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
        // Check global transferability or individual token transferability
        require(
            globalTransferable || transferableTokens[tokenId],
            "Token is not transferable"
        );

        super._transfer(from, to, tokenId);
        _removeTokenFromOwnerEnumeration(from, tokenId);
        _addTokenToOwnerEnumeration(to, tokenId);
    }

    /// @dev Adds a token to the enumeration of owned tokens for a specific address
    /// @param to The address to which the token is being transferred
    /// @param tokenId The ID of the token being added
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    /// @dev Removes a token from the owner enumeration when transferred or burned
    /// @param from The address from which the token is being removed
    /// @param tokenId The ID of the token being removed
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId)
        private
    {
        uint256 lastTokenIndex = _ownedTokens[from].length - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-be-removed token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        _ownedTokens[from].pop();
        delete _ownedTokensIndex[tokenId];
    }
}

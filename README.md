# MetaXSeed Contract

The `MetaXSeed` contract is an Ethereum smart contract for minting unique digital assets based on the ERC-721 token standard. It features extended functionalities including EIP-712 signature-based lazy minting, burnability, transfer restrictions, and batch minting capabilities.

## Features

- **ERC-721 Compliance**: Implements all standard functionalities of an ERC-721 (NFT) token.
- **Lazy Minting**: Allows tokens to be minted upon the first transfer to save initial gas costs, using EIP-712 signatures for security.
- **Batch Minting**: Facilitates minting multiple tokens in a single transaction to optimize transaction fees.
- **Transfer Restrictions**: Tokens can be marked as non-transferable based on certain conditions.
- **Burnable Tokens**: Tokens can be burned to decrease the total supply and remove tokens from circulation.
- **Dynamic Signer Management**: Signers for token minting can be dynamically added or removed.

## Technologies

- **Solidity**: Smart contract programming language.
- **Hardhat**: Ethereum development environment for testing, debugging, and deploying contracts.
- **OpenZeppelin**: Library for secure smart contract development.

## Setup

To get started with this project, follow these steps:

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourgithubusername/metaxseed.git
   cd metaxseed
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Create a `.env` file**

   Create a `.env` file in the root directory and add the following variables:

   ```
   SEPOLIA_URL=https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID
   PRIVATE_KEY=your_private_key_here
   SEPOLIA_ETHERSCAN_API_KEY=your_etherscan_api_key_here
   ```

## Testing

To run tests and ensure the contract behaves as expected:

```bash
npx hardhat test
```

This command will execute the test scripts defined in the `test` folder, testing functionalities like minting, batch minting, lazy minting, and burning.

## Deployment

To deploy the contract to the Sepolia network:

1. **Compile the contract**

   ```bash
   npx hardhat compile
   ```

2. **Deploy the contract**

   ```bash
   npx hardhat run scripts/deploy.js --network sepolia
   ```

3. **Verify the contract on Etherscan**

   After deployment, verify the contract on the Sepolia Etherscan to facilitate interaction and verification:

   ```bash
   npx hardhat verify --network sepolia <DEPLOYED_CONTRACT_ADDRESS>
   ```

Replace `<DEPLOYED_CONTRACT_ADDRESS>` with the actual contract address you received upon deployment.

## Contract Interaction

After deployment, interact with the contract functions through Hardhat console or script files or directly via Sepolia Etherscan once verified.

## Contributing

Contributions are welcome! Please feel free to submit pull requests, create issues for bugs and feature requests, and improve documentation.

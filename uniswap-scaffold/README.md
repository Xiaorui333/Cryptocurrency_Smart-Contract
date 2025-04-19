# Uniswap V2 Scaffold

A Next.js application that provides a natural language interface for interacting with Uniswap V2 pools. Users can perform swaps, add/remove liquidity, and analyze pool data using natural language instructions.

## Prerequisites

- Node.js (v16 or later)
- npm or yarn
- An Ethereum wallet (MetaMask recommended)
- OpenAI API key (for OpenAI LLM support)
- other servers if you like

## Running the Application

1. Start the development server:
```bash
npm run dev
# or
yarn dev
```

2. Open your browser and navigate to https://uniswapscaffoldtenderly-84bwgcpqp-xiaorui333s-projects.vercel.app/

3. Connect to MetaMask,and import account using tenderly sepolia test net https://sepolia.gateway.tenderly.co/3LHjq0femh1vQGSzIVMCy5

4. Get your test faucet before start

## Usage Guide

### Smart contract interactions 

1. Approve token
2. Add Liquidity – to supply token pairs to the pool
3. Remove Liquidity – to withdraw liquidity
4. Swap – for token exchanges, support 

### Pool Analytics

The application provides two main analytics views:
1. **Reserves Curve**:
   - Visualizes the constant product formula (x * y = k)
   - Shows current reserves and k value
   - Displays movement trajectory for swaps and liquidity changes
2. **Swap Price Distribution**:
   - Shows the distribution of swap prices
   - Helps analyze trading patterns and price impact

### Natural Language Interface

1. Navigate to the "LLM Interaction" page
2. Choose your preferred LLM (OpenAI or Custom LLM)
3. Enter your instruction in natural language, for example:
   - "Swap 0.1 ETH for USDC"
   - "Add 1000 USDC and 0.5 ETH as liquidity"
   - "Show me the pool analytics"
   - "How many swaps occurred in the last 24 hours?"

### Task Evaluation

1. Navigate to the "Task Evaluation" page
2. Enter your task description
3. The system will process your request using both LLMs and display:
   - Raw LLM responses
   - SQL query results (if applicable)
   - Natural language answers
   - Relevant contract operation interfaces

## Future improvement

1. Support more pool types and multi-token routing


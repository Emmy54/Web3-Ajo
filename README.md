# Web3Ajo

A decentralized, Web3-native implementation of the traditional **Ajo (Rotational Savings)** system used in South-West Nigeria.

This project is built as a **learn-as-you-code** exploration of:
- Solidity
- Foundry
- Financial primitives
- Default handling in cooperative finance

## ✨ Features
- Fixed contribution amounts
- Rotational payouts
- Deadline & default detection
- Withdrawable balances for defaulters
- Full revert test coverage (Happy and Fuzz tests coming)

## 🏗 Architecture
- ERC20-based contributions
- Deterministic payout order
- State machine-driven rounds

## 🧪 Testing
```bash
forge test
forge coverage

Built with ❤️ using Foundry.

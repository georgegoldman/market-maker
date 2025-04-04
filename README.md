# 🧠 On-Chain Market Maker on Sui

A custom-built, non-AMM market maker implemented using the [Sui Move](https://docs.sui.io/) language. This project allows users (or a designated bot) to place and match limit orders on-chain, similar to a CLOB (Central Limit Order Book). Designed for full control over spread, pricing, and execution — this is ideal for building your own trading strategies on-chain.

## 🚀 Features

- 🔄 Place **bid** and **ask** orders with custom price and amount
- ⚖️ Match trades using simple limit order logic
- 💼 On-chain order book storage using Sui Move
- 🤖 Off-chain bot TypeScript to automate quoting
- 🧩 Plug-and-play architecture for integrating different token pairs
- 🔒 Optional access control to restrict market making to your bot only

## 🧩 Architecture

| Layer         | Responsibility                            |
|---------------|---------------------------------------------|
| `Move Module` | Stores and manages bid/ask orders          |
| `Bot`         | Monitors prices, places and cancels orders |
| `User`        | Interacts with order book and executes trades |
| `Coin`        | Sui-compatible fungible tokens              |


## 📦 Module Structure


📁 move/ ├── MarketMaker.move # Main logic for placing and matching orders ├── Order.move # Order struct and utilities └── OrderBook.move # OrderBook object and storage

```
public struct OrderBook< X: store, Y: store> has key, store {
    id: UID,
    bids: Table<u64, vector<Order<X>>>,
    asks: Table<u64, vector<Order<Y>>>,
    best_bid: u64,
    best_ask: u64
}
```

- bids is a Table that contain list of bids in category or pricing
- asks is a Table that contain list of asks in category or pricing
- Then there is best_bid and best_ask that is mutable base on the current market state

## 🛡️ Security Considerations

- ⚠️ Prevent spam with minimum order sizes or collateral

- ⛔ Optional access control: allow only specific addresses to place orders

- 🛑 Cancel stale orders to protect from adverse selection


## 📚 Future Enhancements

- Order matching engine with best-price-first logic
- Order expiration support
- Order cancellation and edit support
- Token pair support (e.g. different trading markets)
- Gas-efficient design for large order books

## 🧪 Getting Started

1. Install Sui CLI: https://docs.sui.io/build/install
2. Clone this repo
3. Deploy the Move module

## License

MIT License

### Built with ❤️ on Sui
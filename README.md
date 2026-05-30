# Hermes

**Hermes** is a hardware-accelerated market making engine built entirely on an FPGA.

It receives live CME MDP 3.0 market data directly from Ethernet, reconstructs a real-time order book in hardware, computes fair value from market microstructure signals, and submits quotes back to the exchange over iLink3/FIXP — all with deterministic latency and no CPU in the execution path.

Built on the Digilent Arty A7-35T (Artix-7 XC7A35T).

---

## System Overview

Hermes implements the full trading pipeline directly in RTL:

```text
CME MDP 3.0 Market Data
        ↓
Ethernet / IPv4 / UDP
        ↓
   MDP 3.0 Parser
        ↓
  10-Level Order Book
        ↓
 Market Making Engine
(VWAP + OFI + Inventory Skew)
        ↓
 Risk Engine / Quote Logic
        ↓
 iLink3 / FIXP Order Entry
        ↓
 TCP / IP / Ethernet
```

Incoming market data is parsed directly on the FPGA. Book state updates in real time, fair value is recomputed continuously, and quotes are serialized back onto the wire as exchange-native order entry messages.

The full receive-to-transmit trading path runs entirely in hardware.

---

## Market Data + Order Book

Hermes includes a hardware parser for CME **MDP 3.0** multicast market data with support for incremental refresh, snapshot refresh, and trade summary messages.

Market data updates feed into an on-chip **10-level bid/ask order book**, maintained in real time. The book tracks price and size at each level, validates packet sequencing, detects feed gaps, and resynchronizes from snapshot data when needed.

This order book acts as the core state store for the strategy engine.

---

## Market Making Engine

The quoting engine computes fair value using multiple market signals:

- **VWAP-weighted mid price** across configurable depth levels
- **Order Flow Imbalance (OFI)** derived from aggressor-side trades
- **Inventory skew** based on current net position

Rather than quoting around the top-of-book midpoint, Hermes prices around estimated fair value and dynamically adjusts quotes based on recent trade pressure and inventory exposure.

Strategy behavior includes:

- configurable quote size and spread
- inventory-aware quote skewing
- directional quoting during strong one-sided flow
- periodic quote refresh to avoid stale resting orders

---

## Risk Controls

Hermes includes built-in pre-trade risk checks in hardware, including:

- maximum net position limits
- order rate limiting
- realized and unrealized P&L monitoring
- quote suppression on market-data desynchronization or risk breach

These checks execute inline with quote generation before any order is transmitted.

---

## Order Entry + Networking

Hermes implements native **CME iLink3 / FIXP** order entry directly in RTL.

The transmit path handles:

- FIXP session negotiation / establishment
- sequence tracking
- heartbeat messaging
- `NewOrderSingle`
- `OrderCancelRequest`

Orders are serialized directly into TCP/IP/Ethernet frames and transmitted without any software networking stack in the path.

Supporting the trading engine is a fully custom hardware networking stack with RTL implementations of:

- Ethernet
- ARP
- IPv4
- UDP
- TCP
- ICMP
- MDIO PHY configuration

Current hardware runs over **100 Mbps MII**, with **RGMII support implemented for future gigabit PHY hardware**.

---

## Hardware

| Component | Value |
|---|---:|
| FPGA | Xilinx Artix-7 XC7A35T |
| Board | Digilent Arty A7-35T |
| PHY | TI DP83848J |
| Interface | MII (100 Mbps), RGMII-ready |
| Toolchain | Vivado 2025.2 |

---

## Verification

Hermes is verified with module-level and full-system simulation testbenches covering:

- market data parsing
- order book updates
- snapshot and incremental replay
- TCP session establishment
- end-to-end quote generation

The design is also structured for hardware-in-the-loop testing using replayed CME MDP3 traffic over Ethernet and iLink connectivity against CME certification environments.

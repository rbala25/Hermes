# Hermes

A hardware-accelerated trading system built from scratch on an FPGA. No soft-core processor, no Linux, no drivers — just RTL all the way from raw Ethernet frames to order book updates, running at line rate.

Built on the Digilent Arty A7-35T (Artix-7). Every layer of the network stack was written by hand in SystemVerilog.

---

## Network Stack

A complete Ethernet stack implemented in hardware. Packets come in off the wire as nibbles and get parsed, validated, and acted on entirely in logic.

- **mii_rx / mii_tx** — PHY interface, preamble/SFD handling, nibble-to-byte serialization
- **eth_parser / eth_tx** — Ethernet header parsing and construction
- **ip_parser / ip_tx** — IPv4 with header checksum validation and generation
- **icmp_parser / icmp_tx** — ICMP echo request/reply with checksum adjustment

The RX and TX clocks are asynchronous (the PHY provides them independently). Clock domain crossing is handled with two-flop synchronizers and a CDC pulse for FIFO pointer resets.

### MII vs RGMII

The stack has two PHY interfaces: **MII** (currently running) and **RGMII** (implemented, waiting on hardware).

The Arty A7's onboard DP83848 PHY only supports MII — 4-bit bus, 25MHz clock, 100Mbps max. RGMII runs the same 4-bit bus but clocks both edges (DDR) at 125MHz, giving 1Gbps. The RGMII implementation is complete and ready to drop in — it just needs a gigabit-capable PHY to talk to.

| Interface | Bus width | Clock | Max throughput |
|-----------|-----------|-------|----------------|
| MII | 4-bit, single edge | 25 MHz | 100 Mbps |
| RGMII | 4-bit, both edges (DDR) | 125 MHz | **1 Gbps** |

With a gigabit PHY swap, the same stack runs at 10x the line rate — roughly 81,000 minimum-size frames per second, or ~125 MB/s of payload throughput.

---

## Ping Responder

The first end-to-end application. Receives an ICMP echo request, buffers the payload in a 256-byte hardware FIFO, and fires a complete echo reply back — MAC swapped, IP swapped, checksum adjusted — entirely in hardware.

Rather than recomputing the ICMP checksum from scratch on the reply, the received checksum is adjusted using ones-complement arithmetic. Changing the type field from 8 to 0 is equivalent to adding 0x0800 to the checksum, so the reply checksum costs a single adder.

**IP:** `192.168.1.100` — `ping 192.168.1.100` and it responds.

---

## Market Data Parser

Parsed CME MDP 3.0 market data feed directly off UDP frames in hardware. Decoded binary-encoded market data messages at line rate with no software in the path.

---

## Order Book

Hardware price-level aggregation engine. Maintained best bid and ask, tracked quantity at each level, and processed order book updates as they arrived off the wire — all in logic, all in a single clock domain.

---

## Order Entry

Low-latency order submission over the exchange's native binary protocol. End-to-end latency from market data in to order out measured in nanoseconds, not microseconds.

---

## Hardware

| | |
|---|---|
| Board | Digilent Arty A7-35T |
| FPGA | Xilinx Artix-7 XC7A35T |
| PHY | Texas Instruments DP83848J (MII, 100Mbps) |
| Interface | MII now, RGMII ready |
| Toolchain | Vivado 2025.2 |

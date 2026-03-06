# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language and Build System

This is a **Tibbo BASIC** embedded firmware project targeting the **WM2000** platform. Source files use `.tbs` (code) and `.tbh` (header/include) extensions. There is no CLI build system — compilation is performed through **Tibbo IDE**, which reads `OSS_Azure_APP1.tpr` and produces `OSS_Azure_APP1.tpc` (bytecode).

- `.tpr` — project configuration (platform, source file list, compiler settings)
- `.tpc` — compiled bytecode output (do not edit)
- `.xtxt` — descriptor files for platform libraries (settings, tables, BLE, filenum)

## Versioning

Firmware version constants are defined in `global.tbh`:
- App firmware: `AZR2.xx.xx` format (current: AZR2.09.01)
- Supervisor PIC: `OSS_SUPR_PIC_FW_xxx.hex`
- Sensor PIC: `OSS_SNS_PIC_FW_xxx.hex`

When bumping firmware versions, update constants in `global.tbh` and include the corresponding `.hex` files in the project root.

## Architecture Overview

### Entry Points and Control Flow

| File | Role |
|------|------|
| `global.tbh` | All global defines, pin assignments, library includes, firmware version constants |
| `main.tbs` | System event handlers — `on_sys_init()` → `boot()`, timer, socket, WiFi, BLE events |
| `boot.tbs` | Hardware initialization — flash mount, settings/tables init, modem selection, sensor detection, battery |
| `device.tbs` | Core device state machine — sensor sampling, telemetry, sleep/wake cycles, cloud migration |

### Application Libraries (`libraries/`)

| Library | Purpose |
|---------|---------|
| `azure.tbs/tbh` | Azure IoT Hub — DPS provisioning, twin sync, telemetry upload, command reception |
| `cellular.tbs/tbh` | LTE modem abstraction — connection management, WiFi/LTE fallback logic |
| `cell.tbs/tbh` | Raw cellular protocol (AT commands, PPP, signal monitoring, SIM management) |
| `http.tbs/tbh` | HTTP/HTTPS client with TLS |
| `modbus.tbs/tbh` | Modbus RTU master over RS485 |
| `mcp23017.tbs/tbh` | MCP23017 IO expander control (16 GPIO lines) |
| `super_i2c.tbs/tbh` | I2C interface abstraction |

### Platform Libraries (`Platforms/src/0_00/`)

Versioned, reusable platform libraries — do not modify unless intentionally updating the platform version: `mqtt/`, `dns/`, `dhcp/`, `sock/`, `sntp/`, `settings/`, `tables/`, `filenum/`, `gprs/`, `pppoe/`, `luis/` (BLE/NFC config), `aggregate/`, `time/`, `wln/` (WiFi).

### Azure IoT Integration

State machine in `libraries/azure.tbs`:
```
NOT_INITIALIZED → NOT_CONNECTED → DEVICE_LOOKUP → PROVISIONING → CONNECTED
```
- Uses DPS (Device Provisioning Service) with X.509 symmetric key authentication
- Twin properties drive remote configuration changes
- TLS certificate: `Cloud_Certificates/DigiCert.cer`

### Network Connectivity

Dual-modem design with automatic fallback:
- **Primary:** WiFi (DHCP or static IP configured via `WAP`/`WPW`/`DH` settings)
- **Fallback:** LTE/Cellular via PPP (APN configured via `GAN`/`GUR`/`GPW` settings)
- Switching logic lives in `device.tbs` and `libraries/cellular.tbs`

### Device Settings

45 persistent settings managed by the `settings` platform library, defined in `settings.xtxt`. Key groups:
- WiFi: `WAP`, `WPW`, `DH`, IP/GW/NM
- Azure: `DVID` (device ID), `SCID` (scope ID), `PKEY` (primary key), `DPSS` (DPS server)
- LTE: `GAN`, `GUR`, `GPW`
- Sensor/Sampling: `STPY` (sensor type), `MBID` (Modbus device ID), `EPT` (sample period), `SPT` (sleep period)

### Hardware Interfaces

- **I2C:** Temperature/humidity (HIH6130), CO2 sensors, MCP23017 IO expander
- **RS485/Serial:** Modbus RTU for external sensor devices
- **BLE:** LUIS-based configuration interface during boot (`luis.xtxt`)
- **NFC:** NTAG for password recovery
- **PIC LVP:** `PIC_LVP.tbs/tbh` — in-field programming of supervisor and sensor PICs

### OTA Firmware Updates

- Main app firmware downloaded via HTTP and managed by the `filenum` library (`filenum.xtxt`)
- Supervisor and sensor PIC firmware programmed in-field via Low Voltage Programming (LVP)
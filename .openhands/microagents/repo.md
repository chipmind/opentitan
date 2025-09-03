# OpenTitan Repository Overview

## Project Description

OpenTitan is an open source silicon Root of Trust (RoT) project that aims to make silicon RoT design and implementation more transparent, trustworthy, and secure. It's administered by lowRISC CIC as a collaborative project to produce high quality, open IP for instantiation as a full-featured product. The project provides hardware, software, and utilities for building secure silicon chips.

## File Structure Overview

This is a monolithic repository ("monorepo") with the following key directories:

- **`hw/`** - Hardware design files including RTL, IP blocks, and top-level designs
  - `hw/ip/` - Individual IP blocks (AES, UART, SPI, etc.)
  - `hw/top_earlgrey/` - Main chip design (Earl Grey)
  - `hw/top_englishbreakfast/` - Simplified chip design
  - `hw/dv/` - Design verification infrastructure
  - `hw/vendor/` - Third-party IP (Ibex RISC-V core, debug module)

- **`sw/`** - Software stack with three main components:
  - `sw/device/` - Firmware running on the OpenTitan chip
  - `sw/otbn/` - Software for the OTBN cryptographic co-processor
  - `sw/host/` - Host-side tools and utilities

- **`doc/`** - Comprehensive documentation
  - `doc/getting_started/` - Setup and build instructions
  - `doc/contributing/` - Contribution guidelines
  - `doc/security/` - Security specifications and threat models

- **`util/`** - Build tools, scripts, and utilities
- **`third_party/`** - External dependencies and tools
- **`rules/`** - Bazel build rules and configurations

## Building and Testing

OpenTitan uses **Bazel** as its primary build system. For new users, **Verilator simulation** is recommended as it uses only free tools.

### Quick Start
```bash
# Build and run a basic test (takes ~1 hour on first run)
./bazelisk.sh test --test_output=streamed --disk_cache=~/bazel_cache //sw/device/tests:uart_smoketest_sim_verilator

# Build all software
./bazelisk.sh build //sw/...

# Build specific targets
./bazelisk.sh build //sw/device/lib/testing/test_rom:test_rom
```

### Prerequisites
- Linux (Ubuntu 22.04 LTS recommended)
- Install dependencies via `apt-requirements.txt` and `python-requirements.txt`
- Bazel (use provided `bazelisk.sh` script for automatic version management)

### Testing Options
- **Verilator**: Free RTL simulation (recommended for beginners)
- **FPGA**: Hardware testing on development boards
- **DV**: Commercial simulators (VCS, Xcelium)

## Development Workflow

1. **Setup**: Follow `doc/getting_started/README.md` for detailed setup instructions
2. **Build**: Use Bazel for all builds (`./bazelisk.sh build //target`)
3. **Test**: Run tests with `./bazelisk.sh test //target`
4. **Documentation**: Available online at [opentitan.org/book/](https://opentitan.org/book/)

## Key Resources

- **Main Documentation**: [opentitan.org/book/](https://opentitan.org/book/)
- **API Documentation**: [opentitan.org/gen/doxy/](https://opentitan.org/gen/doxy/)
- **Contributing Guide**: `CONTRIBUTING.md`
- **Getting Started**: `doc/getting_started/README.md`
- **Software Guide**: `sw/README.md`

The project supports multiple hardware targets and provides comprehensive tooling for both hardware design and software development in the secure silicon domain.
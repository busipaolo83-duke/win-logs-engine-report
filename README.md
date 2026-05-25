# Hardware & Security Diagnostics Tool

## Project Description
This diagnostics tool has been developed to collect, analyze, and centralize key hardware integrity and system security data into a single local graphical interface. The tool is designed with a specific focus on monitoring the status of the Trusted Platform Module (TPM), evaluating Measured Boot parameters, and intercepting critical system events (such as Kernel-Power anomalies or security module communication failures). This enables timely and accurate diagnostic analysis for technical support and troubleshooting purposes.

## Core Features
* **Hardware and Host Analysis:** Identifies key system specifications including Processor, Motherboard, BIOS Revision, RAM capacity and configuration speed, Graphics Card, and active driver versions.
* **Security Environment Auditing:** Provides real-time monitoring for Secure Boot, BitLocker status (Drive C:), Fast Startup configuration, and system Uptime.
* **TPM Module Diagnostics:** Delivers deep insights into the configuration, readiness, and operational status of the local hardware security chip.
* **Measured Boot Telemetry:** Analyzes boot log attestation status against expected security baselines.
* **Critical Event Logging:** Targets and extracts specific error and critical system events from the last 48 hours (e.g., Event ID 41, TPM-WMI errors), isolating crucial failures from generic Windows background noise.
* **Data Export Utilities:** Includes built-in mechanisms for copying individual log entries, exporting comprehensive Markdown reports for technical documentation, and automatically archiving historical snapshots in JSON format.

## System Prerequisites
To ensure successful execution and accurate data collection, the host environment must meet the following minimum requirements:

* **Operating System:** Microsoft Windows 11 (fully updated to the latest stable build).
* **Execution Environment:** PowerShell 7.4 or higher stable release (the `pwsh.exe` executable must be available within the system PATH).
* **Access Privileges:** The backend component requires elevated administrative privileges (Run as Administrator) to query system CIM/WMI namespaces, BitLocker status, and protected system event logs via `Get-WinEvent`.

## File Structure
The standalone package consists of the following components located within the same root directory:
* `Run-Dashboard.ps1`: The PowerShell backend script responsible for data collection and payload generation.
* `template.html`: The interactive frontend user interface driven by Vue.js and Tailwind CSS for dynamic telemetry visualization.
* `README.md`: This documentation and reference file.
* `Launch-Diagnostics.bat`: The executable script for PowerShell.
* `\Archive`: A automatically generated directory where JSON telemetry snapshots are historical archived during each execution loop.

## Security Disclosures and Assurances
This diagnostic tool operates strictly under a read-only paradigm when interacting with local Windows subsystems.
* **No System Alteration:** The tool does not modify system settings, registry keys, environment variables, or local security policies. It does not install persistent background services or modify firmware configurations.
* **Data Privacy and Locality:** All extracted diagnostics remain entirely local to the host machine and are written exclusively within the application directory. No network interfaces are initialized, and no telemetry data is transmitted to external endpoints.
* **Intended Use Case:** This utility is built solely to parse and present system state logs in a legible, standardized layout for auditing, debugging, and professional technical handovers.

## Instructions for Use
1. Extract the application package to a dedicated local directory.
2. Execute the `Launch-Diagnostics.bat` script from an elevated PowerShell session (Run as Administrator).
3. Upon compilation of the system telemetry payload, the interactive diagnostic dashboard will generate and launch automatically within your default web browser.
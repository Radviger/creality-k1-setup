# Creality K1 and K1-Max Setup for Mainsail and Fluidd

This repository provides a step-by-step guide to setting up Mainsail and Fluidd on Creality K1 and K1-Max 3D printers. These steps include installing Entware, necessary dependencies, and configuring the environment.

## Table of Contents
- [Introduction and Purpose](#introduction-and-purpose)
- [Prerequisites](#prerequisites)
- [Installing Entware](#installing-entware)
- [Setting Up the Environment](#setting-up-the-environment)
- [Installing Necessary Packages](#installing-necessary-packages)
- [Configuring Moonraker, Mainsail, and Fluidd](#configuring-moonraker-mainsail-and-fluidd)
- [Running the Setup Script](#running-the-setup-script)
- [Conclusion and Troubleshooting](#conclusion-and-troubleshooting)

## Introduction and Purpose

The Creality K1 and K1-Max 3D printers run on a restricted environment. This guide will help you unlock their potential by setting up Mainsail and Fluidd, which are web interfaces for controlling your 3D printer via Moonraker.

## Prerequisites

- Creality K1 or K1-Max 3D printer with default root access via SSH.
  - **Username:** `root`
  - **Password:** `creality_2023`
- A computer with SSH access to the printer.
- Basic knowledge of using the command line.

## Installing Entware

1. **Download and Install Entware:**
   - SSH into your Creality K1 or K1-Max printer.
   - Run the following commands to install Entware:

     ```sh
     cd /tmp
     wget http://bin.entware.net/mipselsf-k3.4/installer/generic.sh
     sh generic.sh
     ```

2. **Initialize and Update Entware:**

   ```sh
   /opt/bin/opkg update
   /opt/bin/opkg upgrade


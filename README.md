# 🧬 Fay's Molecular Dynamics Suite (Ultimate Edition)

![Version](https://img.shields.io/badge/version-1.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Language](https://img.shields.io/badge/Language-Bash-orange.svg)
![Engine](https://img.shields.io/badge/Engine-AmberTools25-red.svg)

**The All-in-One Automated Molecular Dynamics Simulation Suite powered by AmberTools.** Designed specifically for Linux (Ubuntu/WSL) to streamline the workflow from protein preparation to publication-quality analysis.

---

## ✨ Key Features

### 🧠 1. Intelligent Automation
* **Smart Workspace Manager:** Create, manage, and switch between receptor projects instantly (`w` menu).
* **Auto-Healing Dependency:** Automatically fixes missing dependencies (CMake, Compilers) and provides guided installation for AmberTools.
* **Hybrid Trajectory Support:** Automatically detects and processes both modern **NetCDF (`.nc`)** and legacy **ASCII (`.mdcrd`)** formats.
* **Flexible Folder Standards:** Supports both modern academic naming (`relax` folder) and legacy naming (`equil` folder) for backward compatibility.

### ⚡ 2. Advanced Ligand Parameterization
* **Auto-Antechamber:** No more manual command typing. Just provide a `.mol2` file.
* **Smart Charge Detection:** Automatically estimates ligand net charge (0, +1, -1).
* **Fail-Safe Retry Loop:** If Antechamber fails (e.g., odd electrons), the script allows instant charge correction without restarting the process.

### 📊 3. Publication-Ready Analysis
* **Journal-Ready Plotter (P3):** Generates high-resolution **PNG** graphs for RMSD, Density, Temperature, and Energy using Python (Matplotlib).
* **Smart H-Bond Analysis:** Auto-detects ligand masks (`:LIG`) and protein residues without manual numbering.
* **MMGBSA Calculation:** Automated binding free energy calculation with correct topology mapping.

### 🎓 4. Educational Mode
* **Built-in Cheat Sheet:** Learn the *Why* and *How* of MD Simulations (RMSD vs RMSF, Why 300K, Why Minimization) directly inside the tool.

---

## 🚀 Quick Install

### Prerequisites
* **OS:** Windows 10/11 (WSL2 with Ubuntu) or Native Linux.
* **Git:** (Optional, for cloning).

Choose how you want to run the suite.

### ⚡ Option 1: Instant Run (No Save)
Run the suite directly from memory without cluttering your disk. Perfect for quick checks or one-time use.
*Note: You must remain online to re-run this command.*

```bash
bash <(curl -sL https://raw.githubusercontent.com/fay-barokah/Fay-MDS-Suite/main/release/1.0/fay-mds-suite.sh)
```
### 💾 Option 2: Download & Install (Persistent)
Download the script to your computer. Recommended for frequent use (works offline after download).

```bash
# 1. Download
curl -sL [https://raw.githubusercontent.com/fay-barokah/Fay-MDS-Suite/main/release/1.0/fay-mds-suite.sh](https://raw.githubusercontent.com/fay-barokah/Fay-MDS-Suite/main/release/1.0/fay-mds-suite.sh) -o fay_mds.sh

# 2. Make Executable
chmod +x fay_mds.sh

# 3. Run
./fay_mds.sh
```
---

## 🛠️ Workflow Overview

1.  **Workspace Setup (Module 0):**
    * Create a project (e.g., `1j3j`).
    * **Required:** Place your clean receptor (e.g., `receptor_1j3j_noH.pdb`) in the project folder.

2.  **Assets Preparation:**
    * Create a ligand folder (e.g., `ligand_wra`).
    * **Required:** Provide the `.mol2` file (Gaussian optimized).
    * The script runs `antechamber` -> `parmchk2` -> `tleap` to generate topology (`.prmtop`) and coordinates (`.inpcrd`).

3.  **Simulation Loop (Modules 1-7):**
    * **Minimization:** Removes bad contacts.
    * **Heating:** Raises temp to 300K.
    * **Density:** Equilibrates pressure/density.
    * **Relaxation (Equil):** Stabilizes the system.
    * **Production:** The actual simulation run.

4.  **Analysis (Module 8-9 & P3):**
    * Run **H-Bond** analysis (Protein-Ligand interactions).
    * Run **MMGBSA** (Binding Free Energy).
    * Use **P3 (Plotter)** to generate summary graphs.

    ---

## 📂 File Structure

The suite organizes your data logically:

```text
~/MDS/
└── 1j3j/                     # Receptor Project
    ├── receptor_1j3j_noH.pdb # Input Receptor
    ├── plot/                 # GLOBAL PLOTS (Aggregated results)
    │   └── ligand_wra/       # PNG Graphs for specific ligand
    └── ligand_wra/           # Ligand Workspace
        ├── assets/           # Topology (.prmtop) & Coords (.inpcrd)
        ├── min/              # Minimization output
        ├── heat/             # Heating output
        ├── density/          # Density output
        ├── relax/            # Equilibration/Relaxation (.nc trajectory)
        ├── prod/             # Production (.nc trajectory)
        ├── summary/          # Final Plots & Statistics
        ├── hbond/            # H-Bond Analysis Data
        └── gbsa/             # Binding Energy Results
```
---

## 📜 Citation

If you use this tool for your research, please cite the underlying engines:

1.  **AmberTools:** Case, D.A. et al. (Current Year). Amber. University of California, San Francisco.
2.  **GAFF:** Wang, J., et al. (2004). *J. Comput. Chem.*, 25, 1157-1174.
3.  **Fay MDS Suite:** Fay-MDS-Suite GitHub Repository ([https://github.com/fay-barokah/Fay-MDS-Suite](https://github.com/fay-barokah/Fay-MDS-Suite)).

---

## ⚖️ License

Distributed under the **MIT License**. See `LICENSE` for more information.

> **Disclaimer:** This tool is an automation wrapper. Users should understand the scientific principles of Molecular Dynamics. The author is not responsible for simulation artifacts caused by incorrect chemical inputs.

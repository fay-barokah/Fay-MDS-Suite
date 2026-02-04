#!/bin/bash

# ==============================================================================
#  FAY'S MOLECULAR DYNAMICS SIMULATION SUITE
#  Version: 1.0 (Ultimate Edition: Smart Config, Edu Corner & Auto-Fix)
#  Author: Fay
#  Description: Automated AmberTools Installer, Manager, and Execution Suite
# ==============================================================================

# --- GLOBAL CONFIGURATION ---
SCRIPT_VERSION="1.2.0"  # <--- Change this later when updating to 1.3
AMBER_VERSION="2025"    # <--- Change this when AmberTools26 is released
AMBER_YEAR="2025"
FAY_YEAR="2026"
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_NC='\033[0m' # No Color
BOLD='\033[1m'

# --- LOGGING SYSTEM (NEW) ---
LOG_DIR="$HOME/log-fay-mds"
if [ ! -d "$LOG_DIR" ]; then mkdir -p "$LOG_DIR"; fi

# 1. Create unique log file names based on the current time
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
CURRENT_LOG_FILE="install_${TIMESTAMP}.log"
INSTALL_LOG="$LOG_DIR/$CURRENT_LOG_FILE"

# 2. Setup Latest Log Link (Will be updated during installation)
LATEST_LOG_LINK="$LOG_DIR/install_latest.log"

# Global Variables for Workspace
CURRENT_RECEPTOR_DIR=""
CURRENT_RECEPTOR_NAME=""

pause(){
    echo ""
    read -p "Press [Enter] to continue..." fackEnterKey
}

# --- NEW HELPER: SMART DIRECTORY LISTING (COMPACT VIEW) ---
list_project_items() {
    echo -e "${COLOR_YELLOW}Project Contents [${CURRENT_RECEPTOR_NAME}]:${COLOR_NC}"
    
    if [[ -z "$CURRENT_RECEPTOR_DIR" || ! -d "$CURRENT_RECEPTOR_DIR" ]]; then
        echo "  (No active project)"
        return
    fi

    # Header Table (Adjusted to align with the bracket below)
    printf "  %-11s | %s\n" "TYPE" "NAME"
    echo "  ------------+-----------------------"

    found=false
    for item in "$CURRENT_RECEPTOR_DIR"/*; do
        if [ -d "$item" ]; then
            found=true
            base=$(basename "$item")
            
            # COLORING & PADDING LOGIC (Now %-7s to fit)
            if [[ "$base" == "in" || "$base" == "plot" ]]; then
                printf "  [${COLOR_YELLOW}%-7s${COLOR_NC}] | ${COLOR_YELLOW}%s${COLOR_NC}\n" "SYSTEM" "$base"
            
            elif [ -d "$item/assets" ]; then
                printf "  [${COLOR_GREEN}%-7s${COLOR_NC}] | ${COLOR_GREEN}%s${COLOR_NC}\n" "LIGAND" "$base"
            
            else
                printf "  [${COLOR_RED}%-7s${COLOR_NC}] | ${COLOR_RED}%s${COLOR_NC}\n" "UNKNOWN" "$base"
            fi
        fi
    done
    
    if [ "$found" = false ]; then echo "  (Empty Directory)"; fi
    echo ""
}

# ==============================================================================
# MODULE 0: WORKSPACE MANAGER (CANCEL & FILE INFO ADDED)
# ==============================================================================
workspace_manager() {
    # Check whether this is workspace change mode or initial start
    local is_switching=false
    if [[ -n "$CURRENT_RECEPTOR_DIR" ]]; then is_switching=true; fi

    while true; do
        clear
        echo -e "${COLOR_CYAN}>>> WORKSPACE & RECEPTOR SELECTION <<<${COLOR_NC}"
        if [ "$is_switching" = true ]; then
            echo -e "Current Active: ${COLOR_GREEN}$CURRENT_RECEPTOR_NAME${COLOR_NC}"
        fi
        echo "--------------------------------------------------------"
        
        # 1. Specify Base Directory
        DEFAULT_BASE="$HOME/MDS"
        echo "Default Base Directory: $DEFAULT_BASE"
        echo "Options: [y] Default, [n] Custom Path, [c] Cancel/Exit"
        read -p "Select Option: " use_def
        
        # LOGIK CANCEL
        if [[ "$use_def" == "c" || "$use_def" == "C" ]]; then
            if [ "$is_switching" = true ]; then return; else echo "Exiting..."; exit 0; fi
        fi
        
        if [[ "$use_def" == "n" || "$use_def" == "N" ]]; then
            read -p "Enter Custom Path (Absolute Path): " custom_path
            BASE_DIR="${custom_path%/}"
        else
            BASE_DIR="$DEFAULT_BASE"
        fi
        
        if [[ -z "$BASE_DIR" ]]; then
            echo -e "${COLOR_RED}Error: Path cannot be empty.${COLOR_NC}"
            sleep 1; continue
        fi

        if [ ! -d "$BASE_DIR" ]; then 
            echo "Creating directory: $BASE_DIR"
            mkdir -p "$BASE_DIR"
        fi
        
        # 2. LIST PROJECT (SMART COUNT)
        echo "--------------------------------------------------------"
        echo "Available Receptors in $BASE_DIR:"
        echo ""
        
        if [ -z "$(ls -A "$BASE_DIR")" ]; then
            echo "  (No projects found)"
        else
            printf "  %-20s | %s\n" "PROJECT NAME" "CONTENTS"
            echo "  ---------------------+----------------"
            for d in "$BASE_DIR"/*/; do
                if [ -d "$d" ]; then
                    proj_name=$(basename "$d")
                    lig_count_clean=$(ls -F "$d" | grep "/" | grep -vE "assets/|in/|plot/|hbond/|gbsa/" | wc -l)
                    
                    if [ "$lig_count_clean" -eq 0 ]; then lig_info="${COLOR_RED}Empty${COLOR_NC}";
                    else lig_info="${COLOR_GREEN}$lig_count_clean Ligands${COLOR_NC}"; fi
                    
                    printf "  %-20s | %b\n" "$proj_name" "$lig_info"
                fi
            done
        fi
        echo "--------------------------------------------------------"
        
        # LOOPING INPUT
        while true; do
            echo -e "Type '${BOLD}b${COLOR_NC}' Back to Path, '${BOLD}c${COLOR_NC}' to Cancel."
            read -p "Enter Target Receptor Name (e.g., 1j3j or 'new'): " rec_name
            
            # NAVIGATION FEATURES
            if [[ "$rec_name" == "b" || "$rec_name" == "B" ]]; then break; fi 
            if [[ "$rec_name" == "c" || "$rec_name" == "C" ]]; then
                if [ "$is_switching" = true ]; then return; else echo "Exiting..."; exit 0; fi
            fi

            if [[ -z "$rec_name" ]]; then 
                echo -e "${COLOR_RED}Error: Name cannot be empty.${COLOR_NC}"; continue
            fi
            
            CURRENT_RECEPTOR_NAME="$rec_name"
            CURRENT_RECEPTOR_DIR="$BASE_DIR/$rec_name"
            
            if [ ! -d "$CURRENT_RECEPTOR_DIR" ]; then
                echo -e "\n${COLOR_YELLOW}Creating new receptor project: $rec_name${COLOR_NC}"
                mkdir -p "$CURRENT_RECEPTOR_DIR"
            fi
            
            rec_pdb="$CURRENT_RECEPTOR_DIR/receptor_${rec_name}_noH.pdb"
            
            if [ ! -f "$rec_pdb" ]; then
                echo -e "\n${COLOR_RED}[ATTENTION] Clean Receptor PDB missing!${COLOR_NC}"
                echo "Please place your H-removed receptor file here:"
                echo "  Folder : $CURRENT_RECEPTOR_DIR/"
                echo "  File   : receptor_${rec_name}_noH.pdb"
                echo ""
                read -p "I have placed the file (Press Enter to continue)..."
                if [ ! -f "$rec_pdb" ]; then 
                    echo -e "${COLOR_RED}File still not found. Please try again.${COLOR_NC}"
                    continue
                fi
            else
                # MORE CLEAR FILE INFO
                echo -e "\n${COLOR_GREEN}Receptor file detected:${COLOR_NC}"
                echo -e "  -> ${BOLD}$(basename "$rec_pdb")${COLOR_NC}"
            fi
            
            export CURRENT_RECEPTOR_DIR
            export CURRENT_RECEPTOR_NAME
            sleep 1
            return 0
        done
    done
}

check_updates() {
    # YOUR RAW GITHUB URL (Adjust the path: main/tester or main/stable)
    # Assuming we're checking the 'tester' version
    REMOTE_URL="https://raw.githubusercontent.com/capt-fay/Fay-MDS-Suite/main/tester/fay_mds_suite_tester.sh"
    
    echo -e "\n${COLOR_CYAN}>>> CHECKING FOR UPDATES <<<${COLOR_NC}"
    echo "Local Version  : v$SCRIPT_VERSION"
    echo "Checking GitHub..."

    # Fetch the "Version:" line from GitHub (5 second timeout)
    REMOTE_INFO=$(curl -s --max-time 5 "$REMOTE_URL" | grep "Version:" | head -n 1)
    
    if [[ -z "$REMOTE_INFO" ]]; then
        echo -e "${COLOR_RED}Error: Could not connect to GitHub or parse version.${COLOR_NC}"
        echo "Please check your internet connection."
        pause; return
    fi

    # Extract version number (eg: 1.2.0)
    REMOTE_VER=$(echo "$REMOTE_INFO" | awk '{print $3}')
    
    echo "Remote Version : v$REMOTE_VER"
    
    if [[ "$SCRIPT_VERSION" != "$REMOTE_VER" ]]; then
        echo -e "\n${COLOR_GREEN}🎉 NEW VERSION AVAILABLE!${COLOR_NC}"
        echo "Changelog: (Check GitHub Releases)"
        echo ""
        read -p "Update now? (This will overwrite the script) (y/n): " up_yn
        if [[ "$up_yn" == "y" ]]; then
            echo "Updating..."
            # Download and overwrite this script file yourself ($0)
            curl -L "$REMOTE_URL" -o "$0"
            chmod +x "$0"
            echo -e "${COLOR_GREEN}Update Success! Please restart the script.${COLOR_NC}"
            exit 0
        fi
    else
        echo -e "\n${COLOR_GREEN}You are using the latest version.${COLOR_NC}"
    fi
    pause
}

# ==============================================================================
# MODULE 1: EULA, MANUAL & CITATION HELPER
# ==============================================================================

show_eula() {
    clear
    echo -e "${COLOR_BLUE}=====================================================${COLOR_NC}"
    echo -e "${COLOR_BLUE}       FAY'S MOLECULAR DYNAMICS SIMULATION SUITE     ${COLOR_NC}"
    echo -e "${COLOR_BLUE}                   Version: v${SCRIPT_VERSION}               ${COLOR_NC}"
    echo -e "${COLOR_BLUE}=====================================================${COLOR_NC}"
    echo ""
    echo -e "${COLOR_YELLOW}LICENSE & COPYRIGHT:${COLOR_NC}"
    echo -e "This software is licensed under the ${BOLD}MIT License${COLOR_NC}."
    echo "Copyright (c) $FAY_YEAR Fay."
    echo "You are free to use, copy, modify, and distribute this software,"
    echo "provided that the original copyright notice is included."
    echo ""
    
    # --- ADDED BACK: OFFICIAL RESOURCES ---
    echo -e "${COLOR_YELLOW}OFFICIAL RESOURCES:${COLOR_NC}"
    echo -e "📂 ${BOLD}Source Code & Updates${COLOR_NC} :"
    echo -e "   https://github.com/capt-fay/Fay-MDS-Suite"
    echo -e "   (Please Star ⭐ the repo if you find this useful!)"
    echo ""
    echo -e "💬 ${BOLD}Community & Support${COLOR_NC} :"
    echo -e "   https://discord.gg/ZQCzTHdM43"
    echo ""
    
    # --- CITATION POLICY ---
    echo -e "${COLOR_YELLOW}SCIENTIFIC CITATION POLICY:${COLOR_NC}"
    echo -e "1. ${BOLD}AmberTools${COLOR_NC}: If you publish results obtained with this tool,"
    echo "   you MUST cite AmberTools${AMBER_VERSION} (see Menu 'c' for text)."
    echo -e "2. ${BOLD}Fay MDS Suite${COLOR_NC}: We kindly request an acknowledgment or"
    echo "   citation of this repository if it streamlined your workflow."
    echo ""
    echo -e "${COLOR_YELLOW}DISCLAIMER:${COLOR_NC}"
    echo -e "1. This tool is for ${BOLD}Educational & Research purposes${COLOR_NC}."
    echo "2. The author is not responsible for simulation errors, data loss,"
    echo "   or scientific misinterpretations derived from this tool."
    echo "3. Always verify your topology and results manually."
    echo "----------------------------------------------------------------"
    
    read -p "Do you accept these terms? (y/n): " choice
    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "Exiting..."
        exit 0
    fi
}

manual_workflow() {
    clear
    echo -e "${COLOR_CYAN}>>> USER MANUAL & WORKFLOW <<<${COLOR_NC}"
    echo "----------------------------------------------------------------"
    echo -e "${COLOR_YELLOW}1. WORKSPACE & NAVIGATION (Module 0 & w)${COLOR_NC}"
    echo "   - Start by selecting a Receptor Project (e.g., '1j3j')."
    echo "   - REQUIRED: Place 'receptor_noH.pdb' in ~/MDS/<Project>/."
    echo "   - Use menu 'w' to switch active projects without exiting."
    echo ""
    echo -e "${COLOR_YELLOW}2. ASSETS PREPARATION (Module 0)${COLOR_NC}"
    echo "   - Automates Antechamber (GAFF2/BCC) & Parmchk2."
    echo "   - Features: Smart Charge Detector (Auto-suggests 0, +1, -1)."
    echo "   - Generates Topology (prmtop) & Coordinate (inpcrd)."
    echo "   - Create a Ligand Name (e.g., 'ligand_01')."
    echo "   - REQUIRED: Provide the .mol2 file (Gaussian optimized)."
    echo "   - System generates Topology (prmtop) & Coordinate (inpcrd)."
    echo "   - System auto-combines Receptor + Ligand -> Solvated Box."
    echo ""
    echo -e "${COLOR_YELLOW}3. SMART CONFIGURATION (Module i)${COLOR_NC}"
    echo "   - View/Edit Simulation Steps & Temperature."
    echo "   - Smart Sampling: Auto-adjusts print frequency for smooth plots."
    echo ""
    echo -e "${COLOR_YELLOW}4. SIMULATION LOOP (Module 1-7)${COLOR_NC}"
    echo "   - Order: Min -> Heat -> Density -> Equil -> Prod."
    echo "   - Output: Equil phase uses 'relax' folder standard."
    echo "   - Features: Auto-Resume (prevents overwrite) & Live Monitor."
    echo "   - Background: Press Ctrl+C -> 'g' to run in background."
    echo ""
    echo -e "${COLOR_YELLOW}5. ANALYSIS & PUBLICATION (Module 8-P3)${COLOR_NC}"
    echo "   - Run MMGBSA (Binding Energy) & H-Bond Analysis."
    echo "   - Smart Detect: Auto-reads .nc (modern) or .mdcrd (legacy)."
    echo "   - Use 'P3' to generate Journal-Ready plots (Density, RMSD, Stats)."
    echo "   - Use 'c' to copy Citation Text for your paper."
    echo ""
    echo -e "${COLOR_YELLOW}6. SYSTEM MAINTENANCE (Module d & u)${COLOR_NC}"
    echo "   - Use 'd' to Install/Remove AmberTools."
    echo "   - Use 'u' to Check for Script Updates from GitHub."
    echo "----------------------------------------------------------------"
    pause
}

# --- SUB-MENU: MDS FUNDAMENTALS (EDU CORNER) ---
manual_science() {
    clear
    echo -e "${COLOR_CYAN}>>> MDS FUNDAMENTALS: CHEAT SHEET <<<${COLOR_NC}"
    echo "Essential concepts for understanding your simulation results."
    echo "----------------------------------------------------------------"
    
    echo -e "${COLOR_YELLOW}[1] WHY MINIMIZATION FIRST?${COLOR_NC}"
    echo "    - Before heating, we must remove 'Bad Contacts' (Clashes)."
    echo "    - Imagine untangling headphone wires before using them."
    echo "    - Success Indicator: Potential Energy should drop significantly"
    echo "      (become more negative) during this phase."
    echo ""

    echo -e "${COLOR_YELLOW}[2] CONFIG FILES (.in)${COLOR_NC}"
    echo "    These are the 'Brain' of the simulation. They tell Amber:"
    echo "    - How many steps to run (nstlim)."
    echo "    - How often to save data (ntwx)."
    echo "    - What physics to apply (Thermostat/Barostat)."
    echo ""
    
    echo -e "${COLOR_YELLOW}[3] WHY 300 KELVIN?${COLOR_NC}"
    echo "    - 300 K is approx 27°C (Room Temperature)."
    echo "    - It is the standard standard for simulating biological systems"
    echo "      in a laboratory environment."
    echo "    - Note: For human body simulations, use 310 K (37°C)."
    echo ""
    
    echo -e "${COLOR_YELLOW}[4] WHY DENSITY ~1.0 g/cm³?${COLOR_NC}"
    echo "    - We solvate the protein in a water box (TIP3P Model)."
    echo "    - Pure water density is 1.0 g/cm³."
    echo "    - If Density stabilizes at ~1.0, it means your system is"
    echo "      properly equilibrated and the water pressure is realistic."
    echo ""
    
    echo -e "${COLOR_YELLOW}[5] WHAT IS RMSD? (Stability Check)${COLOR_NC}"
    echo "    - Root Mean Square Deviation: Measures how much the protein"
    echo "      shape has changed compared to the start."
    echo -e "    - ${COLOR_GREEN}RMSD < 2.0 Å${COLOR_NC} : Very Stable (Good)."
    echo -e "    - ${COLOR_YELLOW}RMSD 2-3 Å${COLOR_NC}   : Acceptable flexibility."
    echo -e "    - ${COLOR_RED}RMSD > 3.0 Å${COLOR_NC}   : Protein might be unfolding/unstable."
    echo ""

    echo -e "${COLOR_YELLOW}[6] RMSD vs. RMSF (The Difference)${COLOR_NC}"
    echo -e "    - ${BOLD}RMSD (Deviation)${COLOR_NC}: Global stability. 'Did the protein change shape?'"
    echo -e "      (Target: < 2.0 Å is stable)."
    echo -e "    - ${BOLD}RMSF (Fluctuation)${COLOR_NC}: Local flexibility. 'Which part is moving?'"
    echo "      High RMSF = Flexible Loops (Normal)."
    echo "      Low RMSF  = Rigid Core / Active Site (Good for binding)."
    echo ""
    
    echo -e "${COLOR_YELLOW}[7] H-BONDS (Molecular Velcro)${COLOR_NC}"
    echo "    - Hydrogen bonds hold the ligand inside the receptor."
    echo "    - Standard Criteria used in this tool:"
    echo "      1. Distance < 3.5 Å (Angstroms)."
    echo "      2. Angle    > 120 Degrees."
    echo "    - More stable H-Bonds usually mean better affinity."
    echo ""

    echo -e "${COLOR_YELLOW}[8] MMGBSA & DELTA TOTAL${COLOR_NC}"
    echo "    - Calculates Binding Free Energy (Strength of interaction)."
    echo "    - The 'Score' of how strong the ligand binds to the protein."
    echo "    - Formula: ΔG_bind = G_complex - (G_receptor + G_ligand)"
    echo -e "    - ${COLOR_GREEN}More Negative = Stronger Binding${COLOR_NC} (Better Affinity)."
    echo "    - Example: -40 kcal/mol is stronger than -20 kcal/mol."
    echo "----------------------------------------------------------------"
    pause
}

show_citation() {
    clear
    echo -e "${COLOR_CYAN}>>> CITATION HELPER <<<${COLOR_NC}"
    echo "Please cite the following references in your publication:"
    echo "----------------------------------------------------------------"
    
    echo -e "${COLOR_YELLOW}[1] AmberTools (Primary Engine)${COLOR_NC}"
    echo "    Case, D.A. et al. ($AMBER_YEAR). Amber $AMBER_VERSION. University of California,"
    echo "    San Francisco."
    echo ""
    echo -e "${COLOR_YELLOW}[2] GAFF (General Amber Force Field)${COLOR_NC}"
    echo "    Wang, J., Wolf, R.M., Caldwell, J.W., Kollman, P.A., & Case, D.A."
    echo "    (2004). Development and testing of a general amber force field."
    echo "    J. Comput. Chem., 25, 1157-1174."
    echo ""
    echo -e "${COLOR_GREEN}[3] Workflow Automation (This Suite)${COLOR_NC}"
    echo "    Fay MDS Suite (v${SCRIPT_VERSION}). GitHub Repository."
    echo "    URL: https://github.com/capt-fay/Fay-MDS-Suite"
    echo "----------------------------------------------------------------"
    echo -e "${BOLD}Example Acknowledgement:${BOLD}"
    echo "\"Molecular dynamics simulations were performed using AmberTools$AMBER_VERSION"
    echo " (Case et al., $AMBER_YEAR) with GAFF parameters (Wang et al., 2004),"
    echo " automated via Fay MDS Suite v${SCRIPT_VERSION} (Fay, $FAY_YEAR).\""
    echo "----------------------------------------------------------------"
    pause
}

show_manual() {
    while true; do
        clear
        echo -e "${COLOR_CYAN}>>> KNOWLEDGE BASE & MANUAL <<<${COLOR_NC}"
        echo "---------------------------------------"
        echo " 1. Workflow Guide (Technical)"
        echo " 2. MDS Fundamentals (Scientific Concepts)"
        echo " b. Back to Main Menu"
        echo "---------------------------------------"
        read -p "Select Option: " opt
        
        case $opt in
            1) manual_workflow ;;
            2) manual_science ;;
            b|B) return ;;
            *) ;;
        esac
    done
}

# ==============================================================================
# MODULE 2: SYSTEM & DEPENDENCY MANAGER (WITH DOWNLOAD HELPER & AUTO-FIX CMAKE)
# ==============================================================================
dependency_manager() {
    PROG_DIR="$HOME/Programs"

    while true; do
        clear
        echo -e "${COLOR_CYAN}>>> SYSTEM & DEPENDENCY MANAGER <<<${COLOR_NC}"
        echo "Logs Directory       : $LOG_DIR"
        echo "Current Log File     : $CURRENT_LOG_FILE"
        echo "Source Directory     : $PROG_DIR" 
        echo "--------------------------------------------------------"
        
        # --- 1. DETECT INSTALLED VERSIONS ---
        if command -v cmake &> /dev/null; then
            cver=$(cmake --version | head -n1 | awk '{print $3}')
            cmake_status="[${COLOR_GREEN}INSTALLED${COLOR_NC}] v$cver"
        else
            cmake_status="[${COLOR_RED}MISSING${COLOR_NC}]"
        fi

        # --- INTELLIGENT AMBER VERSION CHECK ---
        aver=""
        if command -v sander &> /dev/null; then
            sander_loc=$(command -v sander)
            
            # STRATEGY 1: Check Log
            if [ -f "$LATEST_LOG_LINK" ]; then
                log_ver=$(grep -m 1 "configuration of Amber version" "$LATEST_LOG_LINK" | awk '{print $NF}' | sed 's/\.\.\.//')
                if [[ -n "$log_ver" ]]; then aver="$log_ver (Log)"; fi
            fi

            # STRATEGY 2: Check Folder Name
            if [[ -z "$aver" ]]; then
                path_ver=$(echo "$sander_loc" | grep -iEo "amber(tools)?[0-9]+" | grep -Eo "[0-9]+" | head -n 1)
                if [[ -n "$path_ver" ]]; then aver="$path_ver.0 (Path)"; fi
            fi

            # STRATEGY 3: Check NAB
            if [ -z "$aver" ] && command -v nab &> /dev/null; then
                nab_out=$(nab --version 2>&1)
                nab_ver=$(echo "$nab_out" | grep -Eo "[0-9]+\.[0-9]+" | head -n 1)
                if [[ -n "$nab_ver" ]]; then aver="$nab_ver (Nab)"; fi
            fi

            # STRATEGY 4: Check TLEAP
            if [ -z "$aver" ] && command -v tleap &> /dev/null; then
                out=$(echo "quit" | tleap -f /dev/null 2>&1)
                ver=$(echo "$out" | grep -Eo "AmberTools [0-9.]+" | awk '{print $2}')
                if [[ -n "$ver" ]]; then aver="$ver"; fi
            fi

            if [[ -z "$aver" ]]; then aver="Detected (Unknown Ver)"; fi
            amber_bin_status="[${COLOR_GREEN}INSTALLED${COLOR_NC}] v$aver"
        else
            amber_bin_status="[${COLOR_RED}MISSING${COLOR_NC}]"
            sander_loc=""
        fi

        # Check Install Path
        install_type="NONE"
        if [ -d "$HOME/amber_install" ]; then
            amber_path_disp="${COLOR_GREEN}$HOME/amber_install${COLOR_NC} (Managed by Fay)"
            install_type="FAY"
        elif [[ -n "$sander_loc" ]]; then
            clean_path=$(dirname $(dirname "$sander_loc"))
            amber_path_disp="${COLOR_YELLOW}System/Manual Install${COLOR_NC} ($clean_path)"
            install_type="MANUAL"
        else
            amber_path_disp="${COLOR_RED}Not Found${COLOR_NC}"
        fi

        # --- 2. DETECT DOWNLOADS ---
        DL_DIR="$HOME/Downloads"
        tar_amber=$(find "$DL_DIR" -maxdepth 1 -iname "amber*.tar.bz2" | sort -V | tail -n 1)
        tar_cmake=$(find "$DL_DIR" -maxdepth 1 -iname "cmake-*.tar.gz" | sort -V | tail -n 1)

        if [[ -n "$tar_amber" ]]; then avail_amber="${COLOR_GREEN}$(basename "$tar_amber")${COLOR_NC}"; else avail_amber="${COLOR_RED}Not Found in ~/Downloads${COLOR_NC}"; fi
        if [[ -n "$tar_cmake" ]]; then avail_cmake="${COLOR_GREEN}$(basename "$tar_cmake")${COLOR_NC}"; else avail_cmake="${COLOR_YELLOW}Not Found (Will use system default)${COLOR_NC}"; fi

        # --- 3. DASHBOARD ---
        echo "CORE COMPONENTS:"
        printf "  %-15s : %b\n" "CMake" "$cmake_status"
        printf "  %-15s : %b\n" "AmberTools" "$amber_bin_status"
        echo -e "  Active Path     : $amber_path_disp"
        
        if [ "$aver" == "Detected (Unknown Ver)" ]; then
            echo -e "  ${COLOR_YELLOW}NOTE: Exact version not detected due to manual install headers.${COLOR_NC}"
        fi

        echo ""
        echo "AVAILABLE SOURCES (Detected in ~/Downloads):"
        echo -e "  Amber Source    : $avail_amber"
        echo -e "  CMake Source    : $avail_cmake"
        echo ""
        echo "COMPILER & UTILITIES:"
        check_util() { if command -v $1 &> /dev/null; then printf "  %-15s : [${COLOR_GREEN}OK${COLOR_NC}]\n" "$2"; else printf "  %-15s : [${COLOR_RED}MISSING${COLOR_NC}]\n" "$2"; fi; }
        check_util "make" "Make"
        check_util "gcc" "GCC"
        check_util "gfortran" "GFortran"
        check_util "python3" "Python 3"

        echo "--------------------------------------------------------"
        echo "Select Action:"
        echo " [1] Install System Dependencies (apt-get packages)"
        echo " [2] Install/Update AmberTools (+CMake if missing)"
        echo " [3] Refresh Environment (Source bashrc)"
        echo " [4] UNINSTALL AmberTools (Clean Remove)"
        echo " [c] Change Source Directory (Currently: $PROG_DIR)"
        echo " [5] Back to Main Menu"
        echo "--------------------------------------------------------"
        
        read -p "Option: " dep_opt
        
        case $dep_opt in
            1)
                echo -e "\n${COLOR_YELLOW}Installing System Dependencies...${COLOR_NC}"
                echo "Please enter password for sudo:"
                {
                    sudo apt update
                    sudo apt install -y build-essential gfortran gcc g++ make \
                                        libssl-dev bc flex bison patch wget \
                                        xorg-dev zlib1g-dev libbz2-dev \
                                        tmux python3 python3-pip python3-numpy \
                                        python3-matplotlib python3-pandas tree
                } 2>&1 | tee -a "$INSTALL_LOG"
                
                ln -sf "$INSTALL_LOG" "$LATEST_LOG_LINK"
                echo -e "${COLOR_GREEN}Done.${COLOR_NC}"
                pause
                ;;
            
            2)
                echo -e "\n${COLOR_YELLOW}>>> AMBERTOOLS INSTALLER/UPDATER <<<${COLOR_NC}"
                echo "Target Source Directory: $PROG_DIR"
                
                if [ ! -d "$PROG_DIR" ]; then mkdir -p "$PROG_DIR"; fi
                
                # FIX PERMISSION
                echo "Fixing permissions for $PROG_DIR..."
                sudo chown -R $USER:$USER "$PROG_DIR"
                
                # --- START NEW DOWNLOAD HELPER ---
                # Loop until file is found or user cancels
                while [[ -z "$tar_amber" ]]; do
                    echo -e "${COLOR_RED}Error: AmberTools source not found!${COLOR_NC}"
                    echo "----------------------------------------------------------------"
                    echo "Please download 'AmberTools25.tar.bz2' manually."
                    echo -e "🔗 Official Link: ${BOLD}https://ambermd.org/GetAmber.php${COLOR_NC}"
                    echo "   (Click 'Download AmberTools25', fill the form if asked)"
                    echo ""
                    echo "   Then move the file to: $HOME/Downloads/"
                    echo "----------------------------------------------------------------"
                    
                    read -p "I have downloaded and placed the file. Check again? (y/n): " recheck
                    if [[ "$recheck" == "y" ]]; then
                        # Double check the Downloads folder
                        tar_amber=$(find "$DL_DIR" -maxdepth 1 -iname "amber*.tar.bz2" | sort -V | tail -n 1)
                        if [[ -n "$tar_amber" ]]; then
                            echo -e "${COLOR_GREEN}File found: $(basename "$tar_amber")${COLOR_NC}"
                            break # Exit the loop, continue installing
                        else
                            echo -e "${COLOR_RED}Still not found in ~/Downloads. Please check the filename.${COLOR_NC}"
                        fi
                    else
                        echo "Cancelled."
                        break
                    fi
                done
                
                # If after the loop there is still no file (user cancel), return to the menu.
                if [[ -z "$tar_amber" ]]; then continue; fi
                # --- END DOWNLOAD HELPER ---

                echo -e "Amber Source : ${COLOR_GREEN}$(basename "$tar_amber")${COLOR_NC}"
                
                should_install_cmake=false
                if [[ -n "$tar_cmake" ]]; then
                    echo -e "CMake Source : ${COLOR_GREEN}$(basename "$tar_cmake")${COLOR_NC}"
                    if command -v cmake &> /dev/null; then
                        echo -e "${COLOR_YELLOW}CMake is already installed.$(cmake --version | head -n1 | awk '{print $3}')${COLOR_NC}"
                        read -p "Do you want to re-install/update CMake from source? (y/n): " c_choice
                        if [[ "$c_choice" == "y" ]]; then should_install_cmake=true; fi
                    else
                        should_install_cmake=true
                    fi
                else
                    echo -e "CMake Source : ${COLOR_YELLOW}None (Using System Default / apt-get)${COLOR_NC}"
                fi
                
                if [ -d "$HOME/amber_install" ]; then
                    echo -e "${COLOR_YELLOW}WARNING: Existing Fay's Installation detected at ~/amber_install${COLOR_NC}"
                    echo "Proceeding will DELETE the old version and replace it with the new one."
                fi
                
                read -p "Start Compilation? (Takes 30-60 mins) (y/n): " confirm
                if [[ "$confirm" != "y" ]]; then continue; fi
                
                if [ -d "$HOME/amber_install" ]; then
                    echo "Removing old version (~/amber_install)..."
                    rm -rf "$HOME/amber_install"
                fi

                # --- START INSTALLATION ---
                {
                    echo "=== INSTALL LOG START: $(date) ==="
                    
                    # 1. Install CMake
                    if [ "$should_install_cmake" = true ]; then
                        echo "Installing CMake from source..."
                        tar zxvf "$tar_cmake" -C "$PROG_DIR"
                        c_dir=$(find "$PROG_DIR" -maxdepth 1 -type d -iname "cmake-*" | head -n 1)
                        if [ -z "$c_dir" ]; then echo "Error: CMake extract failed"; exit 1; fi
                        cd "$c_dir"
                        ./bootstrap && make && sudo make install
                    else
                        echo "Skipping CMake source compilation (Using system cmake)."
                    fi

                    # --- FIX: AUTO-INSTALL CMAKE IF MISSING ---
                    if ! command -v cmake &> /dev/null; then
                         echo "CMake command not found. Attempting auto-install via apt-get..."
                         sudo apt update && sudo apt install -y cmake
                         
                         if ! command -v cmake &> /dev/null; then
                             echo "Error: Failed to install CMake automatically."
                             echo "Please run Option [1] 'Install System Dependencies' first."
                             exit 1
                         fi
                    fi
                    # ------------------------------------------

                    # 2. Extract Amber
                    echo "Checking Amber Source..."
                    existing_src=$(find "$PROG_DIR" -maxdepth 1 -type d -iname "amber*_src" | head -n 1)
                    need_extract=true
                    src_dir=""

                    if [[ -n "$existing_src" ]]; then
                        echo -e "${COLOR_YELLOW}Found existing extracted folder: $(basename "$existing_src")${COLOR_NC}"
                        sudo chown -R $USER:$USER "$existing_src"
                        
                        if [ -f "$existing_src/CMakeLists.txt" ]; then
                            read -p "Skip extraction and use existing folder? (y/n): " skip_ext
                            if [[ "$skip_ext" == "y" ]]; then
                                need_extract=false
                                src_dir="$existing_src"
                            else
                                echo "Removing old folder..."
                                rm -rf "$existing_src"
                            fi
                        else
                            echo "Corrupt folder detected. Re-extracting..."
                            rm -rf "$existing_src"
                        fi
                    fi
                    
                    if [ "$need_extract" = true ]; then
                        echo "Extracting AmberTools to $PROG_DIR ..."
                        tar jxvf "$tar_amber" -C "$PROG_DIR"
                        src_dir=$(find "$PROG_DIR" -maxdepth 1 -type d -iname "amber*_src" | head -n 1)
                    fi
                    
                    if [ -z "$src_dir" ]; then echo "Error: Amber extraction failed"; exit 1; fi
                    
                    # 3. Compile Amber
                    cd "$src_dir"
                    
                    if [ -d "build" ]; then
                        echo "Cleaning previous build artifacts..."
                        rm -rf build
                    fi
                    mkdir -p build; cd build
                    
                    echo "Configuring CMake (Compiling as GNU)..."
                    cmake .. -DCMAKE_INSTALL_PREFIX="$HOME/amber_install" \
                             -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
                             -DCOMPILER=GNU \
                             -DDOWNLOAD_MINICONDA=FALSE \
                             -DAmberTools=TRUE
                    
                    echo "Compiling (AmberTools)..."
                    make -j2
                    
                    echo "Installing..."
                    make install
                    echo "=== INSTALL LOG END ==="
                } 2>&1 | tee -a "$INSTALL_LOG"
                
                ln -sf "$INSTALL_LOG" "$LATEST_LOG_LINK"
                
                CFG="$HOME/.bashrc"
                if ! grep -q "amber_install/amber.sh" "$CFG"; then
                    echo "" >> "$CFG"
                    echo "source $HOME/amber_install/amber.sh" >> "$CFG"
                fi
                
                echo -e "${COLOR_GREEN}Installation Complete. Please Restart Terminal.${COLOR_NC}"
                pause
                ;;
            
            3)
                source ~/.bashrc
                echo "Environment Refreshed."
                pause
                ;;
            
            4)
                echo -e "\n${COLOR_RED}>>> UNINSTALL AMBERTOOLS <<<${COLOR_NC}"
                echo "This will DELETE '$HOME/amber_install' permanently."
                read -p "Type 'DELETE' to confirm: " conf_del
                if [[ "$conf_del" == "DELETE" ]]; then
                    rm -rf "$HOME/amber_install"
                    sed -i '/amber.sh/d' ~/.bashrc
                    echo "AmberTools removed."
                else
                    echo "Cancelled."
                fi
                pause
                ;;
            
            c|C)
                echo -e "\n${COLOR_CYAN}>>> CONFIGURE DIRECTORIES <<<${COLOR_NC}"
                echo "Current Source Directory: $PROG_DIR"
                echo "Use absolute path (e.g., /home/user/Apps)"
                read -p "Enter new path (Leave empty to cancel): " new_path
                if [[ -n "$new_path" ]]; then
                    new_path="${new_path%/}"
                    if [ ! -d "$new_path" ]; then
                        read -p "Create directory? (y/n): " cr_dir
                        if [[ "$cr_dir" == "y" ]]; then mkdir -p "$new_path"; PROG_DIR="$new_path"; fi
                    else
                        PROG_DIR="$new_path"
                    fi
                    sudo chown -R $USER:$USER "$PROG_DIR"
                    echo "Source Directory set to: $PROG_DIR"
                fi
                pause
                ;;
                
            5) return ;;
        esac
    done
}

# ==============================================================================
# MODULE 3: INPUT FILE MANAGER (FIXED PARSER & DENSITY INFO)
# ==============================================================================
input_file_manager() {
    if [[ -z "$CURRENT_RECEPTOR_DIR" ]]; then
        echo -e "${COLOR_RED}No workspace selected! Please go to Module 0 first.${COLOR_NC}"
        pause; return
    fi

    CFG_DIR="$CURRENT_RECEPTOR_DIR/in"

    while true; do
        clear
        echo -e "${COLOR_CYAN}>>> INPUT FILE INSPECTOR & CONFIGURATOR <<<${COLOR_NC}"
        echo -e "Project Location: ${COLOR_YELLOW}$CFG_DIR${COLOR_NC}"
        echo "----------------------------------------------------------------------"
        printf "%-10s | %-15s | %-40s\n" "PHASE" "STATUS" "CONFIG (Step | Temp | Pressure)"
        echo "----------------------------------------------------------------------"
        
        files=("min" "heat" "density" "equil" "prod")
        for f in "${files[@]}"; do
            infile="$CFG_DIR/${f}.in"
            if [ -f "$infile" ]; then
                stat="[${COLOR_GREEN}FOUND${COLOR_NC}]"
                
                if [ "$f" == "min" ]; then
                    # FIX: Take the number right after 'maxcyc='
                    val=$(grep "maxcyc" "$infile" | sed -n 's/.*maxcyc[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
                    conf="Cycles: ${val:-Unknown}"
                else
                    # FIX: Take MD parameters with precision
                    step=$(grep "nstlim" "$infile" | sed -n 's/.*nstlim[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
                    temp=$(grep "temp0" "$infile" | sed -n 's/.*temp0[[:space:]]*=[[:space:]]*\([0-9.]*\).*/\1/p')
                    ntp=$(grep "ntp" "$infile" | sed -n 's/.*ntp[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')

                    # Logic Density/Pressure
                    if [[ "$ntp" == "1" ]]; then 
                        p_stat="${COLOR_GREEN}Press:ON${COLOR_NC}" 
                    else 
                        p_stat="${COLOR_YELLOW}Press:OFF${COLOR_NC}"
                    fi
                    
                    if [[ -z "$temp" ]]; then temp="?"; fi
                    conf="${step} steps | ${temp} K | ${p_stat}"
                fi
            else
                stat="[${COLOR_RED}MISSING${COLOR_NC}]"
                conf="-"
            fi
            
            printf "%-10s | %-25b | %-40b\n" "${f^^}" "$stat" "$conf"
        done
        echo "----------------------------------------------------------------------"
        
        echo "Select Action:"
        echo " [1] Generate Default Input Files (Standard)"
        echo " [2] Edit Minimization (Max Cycles)"
        echo " [3] Edit Equil Phase (Heat+Density+Equil Linked)"
        echo " [4] Edit Production (Smart Sampling)"
        echo " [5] Back to Main Menu"
        
        read -p "Option: " opt
        
        case $opt in
            1)
                echo -e "\n${COLOR_YELLOW}Generating default input files...${COLOR_NC}"
                mkdir -p "$CFG_DIR"
                
                # --- 1. MINIMIZATION ---
                cat > "$CFG_DIR/min.in" <<EOF
Minimize
 &cntrl
  imin=1, ntx=1, irest=0, maxcyc=2000, ncyc=1000, ntpr=100, ntwx=0, cut=8.0,
 /
EOF
                # --- 2. HEATING (NTP=0 for Heat usually) ---
                cat > "$CFG_DIR/heat.in" <<EOF
Heat
 &cntrl
  imin=0, ntx=1, irest=0, nstlim=10000, dt=0.002, ntf=2, ntc=2,
  tempi=0.0, temp0=300.0, ntpr=100, ntwx=100, cut=8.0, ntb=2, ntp=1, taup=2.0,
  ntt=3, gamma_ln=2.0, nmropt=1, ig=-1,
 /
 &wt type='TEMP0', istep1=0, istep2=9000, value1=0.0, value2=300.0, /
 &wt type='END', /
EOF
                # --- 3. DENSITY (NTP=1 ON) ---
                cat > "$CFG_DIR/density.in" <<EOF
Density
 &cntrl
  imin=0, ntx=5, irest=1, nstlim=10000, dt=0.002, ntf=2, ntc=2,
  temp0=300.0, ntpr=100, ntwx=100, cut=8.0, ntb=2, ntp=1, taup=2.0,
  ntt=3, gamma_ln=2.0, ig=-1,
 /
EOF
                # --- 4. EQUILIBRATION (NTP=1 ON) ---
                cat > "$CFG_DIR/equil.in" <<EOF
Equil
 &cntrl
  imin=0, ntx=5, irest=1, nstlim=10000, dt=0.002, ntf=2, ntc=2,
  temp0=300.0, ntpr=100, ntwx=100, cut=8.0, ntb=2, ntp=1, taup=2.0,
  ntt=3, gamma_ln=2.0, ig=-1,
 /
EOF
                # --- 5. PRODUCTION (NTP=1 ON) ---
                cat > "$CFG_DIR/prod.in" <<EOF
Production
 &cntrl
  imin=0, ntx=5, irest=1, nstlim=500000, dt=0.002, ntf=2, ntc=2,
  temp0=300.0, ntpr=1000, ntwx=1000, cut=8.0, ntb=2, ntp=1, taup=2.0,
  ntt=3, gamma_ln=2.0, ig=-1,
 /
EOF
                # --- 6. MMGBSA ---
                cat > "$CFG_DIR/mmgbsa.in" <<EOF
&general
  startframe=1, endframe=500, interval=1, verbose=2,
/
&gb
  igb=5, saltcon=0.15,
/
EOF
                echo -e "${COLOR_GREEN}Success! Files created in $CFG_DIR${COLOR_NC}"
                pause
                ;;
                
            2) # Edit Minimization
                if [ ! -f "$CFG_DIR/min.in" ]; then echo "Generate defaults first!"; pause; continue; fi
                
                # FIX: Ambil value saat ini dengan regex aman
                curr=$(grep "maxcyc" "$CFG_DIR/min.in" | sed -n 's/.*maxcyc[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
                
                read -p "Enter new Max Cycles (current: $curr): " val
                if [[ -n "$val" ]]; then 
                    sed -i "s/maxcyc=[0-9]*/maxcyc=$val/" "$CFG_DIR/min.in"
                    echo -e "${COLOR_GREEN}Updated min.in.${COLOR_NC}"
                fi
                pause ;;
            
            3) # Edit Equil Phase
                if [ ! -f "$CFG_DIR/heat.in" ]; then echo "Generate defaults first!"; pause; continue; fi
                
                echo -e "\n${COLOR_YELLOW}>>> LINKED EDIT MODE (Heat + Density + Equil) <<<${COLOR_NC}"
                
                # FIX: Ambil value aman
                curr=$(grep "nstlim" "$CFG_DIR/heat.in" | sed -n 's/.*nstlim[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
                
                read -p "Enter new NSTEP (current: $curr): " val
                
                if [[ -n "$val" ]]; then 
                    # 1. Update NSTLIM
                    sed -i "s/nstlim=[0-9]*/nstlim=$val/" "$CFG_DIR/heat.in"
                    sed -i "s/nstlim=[0-9]*/nstlim=$val/" "$CFG_DIR/density.in"
                    sed -i "s/nstlim=[0-9]*/nstlim=$val/" "$CFG_DIR/equil.in"
                    
                    # 2. Update Ramping Heat
                    val_ramp=$((val - (val/10) ))
                    sed -i "s/istep2=[0-9]*/istep2=$val_ramp/" "$CFG_DIR/heat.in"
                    
                    # 3. Smart NTPR
                    new_pr=$((val / 50))
                    if [ $new_pr -lt 10 ]; then new_pr=10; fi
                    
                    sed -i "s/ntpr=[0-9]*/ntpr=$new_pr/" "$CFG_DIR/heat.in"
                    sed -i "s/ntwx=[0-9]*/ntwx=$new_pr/" "$CFG_DIR/heat.in"
                    
                    sed -i "s/ntpr=[0-9]*/ntpr=$new_pr/" "$CFG_DIR/density.in"
                    sed -i "s/ntwx=[0-9]*/ntwx=$new_pr/" "$CFG_DIR/density.in"
                    
                    sed -i "s/ntpr=[0-9]*/ntpr=$new_pr/" "$CFG_DIR/equil.in"
                    sed -i "s/ntwx=[0-9]*/ntwx=$new_pr/" "$CFG_DIR/equil.in"

                    echo -e "${COLOR_GREEN}Success! Steps set to $val.${COLOR_NC}"
                fi
                pause ;;
            
            4) # Edit Production
                if [ ! -f "$CFG_DIR/prod.in" ]; then echo "Generate defaults first!"; pause; continue; fi
                
                # FIX: Take safe value
                curr=$(grep "nstlim" "$CFG_DIR/prod.in" | sed -n 's/.*nstlim[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
                
                read -p "Enter new NSTEP (current: $curr): " val
                
                if [[ -n "$val" ]]; then 
                    sed -i "s/nstlim=[0-9]*/nstlim=$val/" "$CFG_DIR/prod.in"
                    
                    # Smart Sampling Logic
                    if [ "$val" -lt 10000 ]; then
                        new_pr=$((val / 100))
                        if [ $new_pr -lt 10 ]; then new_pr=10; fi
                    else
                        new_pr=1000
                    fi
                    
                    sed -i "s/ntpr=[0-9]*/ntpr=$new_pr/" "$CFG_DIR/prod.in"
                    sed -i "s/ntwx=[0-9]*/ntwx=$new_pr/" "$CFG_DIR/prod.in"
                    
                    echo -e "${COLOR_GREEN}Updated prod.in to $val steps.${COLOR_NC}"
                fi
                pause ;;
            
            5) return ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# ==============================================================================
# MODULE 4: SIMULATION ENGINES (FIXED PARSING & DISPLAY)
# ==============================================================================

# --- NEW HELPER: SMART STEP CHECKER ---
get_step_status() {
    local folder="$1"
    local step="$2"
    local target="$3" 
    local logfile="$folder/$step/$step.log"
    local rstfile="$folder/$step/$step.rst"

    STATUS_CODE=0
    
    if [ -f "$rstfile" ]; then
        echo -e "Status: [${COLOR_GREEN}DONE${COLOR_NC}] (Target: $target steps)"
        STATUS_CODE=2
    elif [ -f "$logfile" ]; then
        last_step=$(grep "NSTEP" "$logfile" | tail -n 1 | awk '{print $3}')
        if [[ -z "$last_step" ]]; then last_step=0; fi
        
        # FIX: Make sure the target is considered a number (default 0 if empty)
        target=${target:-0}
        
        if [ "$last_step" -ge "$target" ] && [ "$target" -gt 0 ]; then
             echo -e "Status: [${COLOR_GREEN}DONE${COLOR_NC}] ($last_step of $target steps)"
             STATUS_CODE=2
        else
             echo -e "Status: [${COLOR_YELLOW}PENDING/CRASH${COLOR_NC}] ($last_step of $target steps)"
             STATUS_CODE=1
        fi
    else
        echo -e "Status: [${COLOR_RED}NOT YET RUN${COLOR_NC}]"
        STATUS_CODE=0
    fi
}

# --- NEW HELPER: SMART ANALYSIS CHECKER ---
get_file_timestamp() {
    local file="$1"
    if [ -f "$file" ]; then
        ts=$(date -r "$file" "+%Y-%m-%d %H:%M")
        echo -e "Status: [${COLOR_GREEN}DONE${COLOR_NC}] Generated at: $ts"
        return 0 
    else
        echo -e "Status: [${COLOR_RED}NOT YET RUN${COLOR_NC}]"
        return 1 
    fi
}

# --- HELPER: SMART MONITORING ---
monitor_simulation() {
    local pid=$1
    local lig_folder=$2
    local log_file=$3
    local step_type=$4
    local mdinfo_exact=$5

    # FIX PARSING: Use SED Regex to be accurate (No 'ntx' leaks)
    target_nstep="Unknown"
    if [ -f "in/${step_type}.in" ]; then
        if [ "$step_type" == "min" ]; then
            target_nstep=$(grep "maxcyc" "in/${step_type}.in" | sed -n 's/.*maxcyc[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
        else
            target_nstep=$(grep "nstlim" "in/${step_type}.in" | sed -n 's/.*nstlim[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
        fi
    fi

    trap '
        echo -e "\n${COLOR_YELLOW}>>> MONITORING PAUSED <<<${COLOR_NC}"; 
        echo "Options:";
        echo " [k] KILL Process (Stop Simulation)";
        echo " [b] BACK to Monitor (Resume Viewing)";
        echo " [g] GO Background (Keep running, exit to Menu)";
        read -p "Select [k/b/g]: " choice;
        
        if [[ $choice == "k" ]]; then 
            kill -9 $pid 2>/dev/null; 
            echo -e "\n${COLOR_RED}>>> Simulation KILLED by user.${COLOR_NC}"; 
            rm -f "$mdinfo_exact"; 
            return 1; 
        elif [[ $choice == "g" ]]; then
            echo -e "\n${COLOR_GREEN}>>> Simulation running in background.${COLOR_NC}";
            return 0;
        else 
            echo -e "${COLOR_GREEN}Resuming monitor...${COLOR_NC}"; 
        fi
    ' SIGINT

    echo -e "${COLOR_CYAN}Monitoring PID: $pid | Target Steps: $target_nstep${COLOR_NC}"
    echo "Press [Ctrl+C] to open Options Menu."
    
    while kill -0 $pid 2>/dev/null; do
        clear
        echo -e "${COLOR_BLUE}=== LIVE LOG: $(basename "$log_file") ===${COLOR_NC}"
        tail -n 15 "$log_file"
        echo "-----------------------------------------------------------------------"
        
        if [[ -f "$mdinfo_exact" ]]; then
            if [ "$step_type" == "min" ]; then
                echo -e "${COLOR_GREEN}>>> MINIMIZATION STATUS:${COLOR_NC}"
                grep -E "NSTEP|ENERGY|RMS|GMAX" "$mdinfo_exact" | tail -n 2
            else
                echo -e "${COLOR_GREEN}>>> MD STATUS & ETA:${COLOR_NC}"
                grep -E "NSTEP|TIME|remaining|ns/day" "$mdinfo_exact" | tail -n 2
            fi
        else
            echo -e "${COLOR_YELLOW}Waiting for sander output...${COLOR_NC}"
        fi
        
        echo -e "\n${COLOR_YELLOW}[Ctrl+C] for Menu (Kill/Back/Background)${COLOR_NC}"
        sleep 2
    done
    
    trap - SIGINT 
    
    if ! kill -0 $pid 2>/dev/null; then 
        echo -e "\n${COLOR_GREEN}>>> PROCESS FINISHED. Press Enter. <<<${COLOR_NC}"; 
    fi
}

engine_prepare_assets() {
    # --- BETTER ERROR HANDLING ---
    if ! command -v tleap &> /dev/null; then
        echo -e "\n${COLOR_RED}>>> CRITICAL ERROR: AmberTools (tleap) NOT FOUND! <<<${COLOR_NC}"
        echo "The simulation engine is missing or not loaded in this session."
        echo ""
        echo -e "${COLOR_YELLOW}HOW TO FIX:${COLOR_NC}"
        echo "1. If you JUST installed AmberTools:"
        echo "   -> Close this script, run 'source ~/.bashrc', or RESTART TERMINAL."
        echo "   -> Or go to Menu [d] -> Option [3] (Refresh Environment)."
        echo ""
        echo "2. If you haven't installed it:"
        echo "   -> Go to Menu [d] Dependency Manager -> Option [2] Install."
        echo "----------------------------------------------------------------"
        pause
        return
    fi
    
    # Check other supporting tools (usually in one package with tleap)
    if ! command -v antechamber &> /dev/null; then echo "Error: antechamber missing."; pause; return; fi
    if ! command -v parmchk2 &> /dev/null; then echo "Error: parmchk2 missing."; pause; return; fi

    echo -e "${COLOR_CYAN}>>> SYSTEM SETUP (TOPOLOGY GENERATION) <<<${COLOR_NC}"
    if [[ -z "$CURRENT_RECEPTOR_DIR" ]]; then echo "No workspace."; pause; return; fi

    list_project_items

    read -p "Enter Target Ligand Name (folder only): " lig_name
    if [[ -z "$lig_name" ]]; then echo "Cancelled."; return; fi

    WORK_DIR="$CURRENT_RECEPTOR_DIR/$lig_name"
    if [ ! -d "$WORK_DIR" ]; then
        echo -e "${COLOR_YELLOW}Creating folder: $lig_name${COLOR_NC}"
        mkdir -p "$WORK_DIR"
    fi
    ASSETS_DIR="$WORK_DIR/assets"
    if [ ! -d "$ASSETS_DIR" ]; then mkdir -p "$ASSETS_DIR"; fi

    # --- 1. RECEPTOR SETUP ---
    STD_REC="receptor_noH.pdb"
    if [ ! -f "$ASSETS_DIR/$STD_REC" ]; then
        if [ -f "$CURRENT_RECEPTOR_DIR/receptor_${CURRENT_RECEPTOR_NAME}_noH.pdb" ]; then
            cp "$CURRENT_RECEPTOR_DIR/receptor_${CURRENT_RECEPTOR_NAME}_noH.pdb" "$ASSETS_DIR/$STD_REC"
            echo -e "Auto-Copied    : ${COLOR_GREEN}$STD_REC${COLOR_NC}"
        else
            echo -e "${COLOR_RED}Standard receptor not found!${COLOR_NC}"
            read -p "Enter custom PDB path: " manual_pdb
            if [[ -z "$manual_pdb" ]]; then return; fi
            cp "$manual_pdb" "$ASSETS_DIR/$STD_REC"
        fi
    else
        echo -e "Using Receptor : ${COLOR_GREEN}$STD_REC${COLOR_NC}"
    fi

# --- 2. LIGAND SETUP (FIXED LOOP) ---
    echo "Searching for ligand (.mol2)..."
    RAW_MOL2=""
    
    while true; do
        if [ -f "$ASSETS_DIR/$lig_name.mol2" ]; then RAW_MOL2="$ASSETS_DIR/$lig_name.mol2"; 
        elif [ -f "$ASSETS_DIR/ligand.mol2" ]; then RAW_MOL2="$ASSETS_DIR/ligand.mol2"; 
        elif [ -n "$(find "$ASSETS_DIR" -maxdepth 1 -name "*.mol2" ! -name "*gaff*" | head -n 1)" ]; then
             RAW_MOL2=$(find "$ASSETS_DIR" -maxdepth 1 -name "*.mol2" ! -name "*gaff*" | head -n 1)
        else
            found_out=$(find "$WORK_DIR" -maxdepth 1 -name "*.mol2" ! -name "*gaff*" | head -n 1)
            if [ -n "$found_out" ]; then
                cp "$found_out" "$ASSETS_DIR/$(basename "$found_out")"
                RAW_MOL2="$ASSETS_DIR/$(basename "$found_out")"
            fi
        fi

        if [ -n "$RAW_MOL2" ]; then break; fi
        
        echo -e "\n${COLOR_YELLOW}[ACTION REQUIRED] .mol2 file missing!${COLOR_NC}"
        echo "Place your raw ligand file in: $ASSETS_DIR/"
        read -p "Filename (e.g. compound.mol2) or 'c' to cancel: " user_mol2
        
        if [[ "$user_mol2" == "c" ]]; then return; fi
        
        if [ -f "$ASSETS_DIR/$user_mol2" ]; then
             RAW_MOL2="$ASSETS_DIR/$user_mol2"
             break
        else
             echo -e "${COLOR_RED}File '$user_mol2' not found in assets directory.${COLOR_NC}"
        fi
    done
    
    RAW_NAME=$(basename "$RAW_MOL2")
    echo -e "Raw Ligand     : ${COLOR_YELLOW}$RAW_NAME${COLOR_NC}"
    
    # --- 3. PARAMETERIZATION (SMART CHARGE & RETRY LOOP) ---
    current_dir=$(pwd)
    cd "$ASSETS_DIR" || return

    GAFF_MOL2="${lig_name}.gaff2.mol2"
    FRCMOD_NAME="${lig_name}.frcmod"
    
    if [ -f "$GAFF_MOL2" ] && [ -f "$FRCMOD_NAME" ]; then
        echo -e "${COLOR_GREEN}Existing GAFF2 parameters found. Skipping Antechamber.${COLOR_NC}"
    else
        echo -e "\n${COLOR_CYAN}>>> LIGAND CONFIGURATION (Antechamber) <<<${COLOR_NC}"
        
        # --- SMART CHARGE DETECTION ---
        # Try calculating the total charge from the last column in the mol2 file (if any)
        detected_charge=0
        if [ -f "$RAW_NAME" ]; then
            # Sum column 9 (charge) in the ATOM section
            sum_chg=$(sed -n '/<TRIPOS>ATOM/,/<TRIPOS>BOND/p' "$RAW_NAME" | grep -v "TRIPOS" | awk '{s+=$9} END {printf "%.0f", s}')
            # If the output is empty/not a number, default is 0
            if [[ "$sum_chg" =~ ^-?[0-9]+$ ]]; then detected_charge=$sum_chg; fi
        fi
        # -----------------------------

        # RETRY LOOP (Fail-Safe)
        while true; do
            echo "----------------------------------------------------"
            echo -e "Detected/Recommended Charge: ${COLOR_GREEN}$detected_charge${COLOR_NC}"
            echo -e "${COLOR_YELLOW}Quick Guide:${COLOR_NC}"
            echo "  0 = Neutral (General organic molecules)"
            echo "  1 = Positive Cation (e.g., Protonated Amines)"
            echo " -1 = Negative Anion (e.g., Carboxylates)"
            echo "----------------------------------------------------"
            
            read -p "Enter Net Charge [Default: $detected_charge]: " user_nc
            NET_CHARGE=${user_nc:-$detected_charge}
            
            echo "Calculating charges (BCC) with Net Charge: $NET_CHARGE ..."
            antechamber -i "$RAW_NAME" -fi mol2 -o "$GAFF_MOL2" -fo mol2 -c bcc -nc $NET_CHARGE -at gaff2 > antechamber.log 2>&1
            
            if [ -f "$GAFF_MOL2" ]; then
                echo -e "${COLOR_GREEN}Antechamber Success!${COLOR_NC}"
                break # Exit loop on success
            else
                echo -e "${COLOR_RED}Antechamber Failed!${COLOR_NC}"
                
                # Check for specific error "Odd number of electrons"
                if grep -q "odd number of electrons" antechamber.log; then
                    echo -e "${COLOR_YELLOW}Hint: The molecule has an ODD number of electrons.${COLOR_NC}"
                    echo "This usually means the Net Charge is wrong."
                    echo "Try changing charge to $((NET_CHARGE + 1)) or $((NET_CHARGE - 1))."
                else
                    echo "Check antechamber.log for details."
                    tail -n 5 antechamber.log
                fi
                
                echo ""
                read -p "Do you want to retry with a different charge? (y/n): " retry_yn
                if [[ "$retry_yn" != "y" ]]; then
                    cd "$current_dir"; pause; return
                fi
                # If 'y', the loop will repeat and ask for charge again
            fi
        done

        echo "Generating Parameters (Parmchk2)..."
        parmchk2 -i "$GAFF_MOL2" -f mol2 -o "$FRCMOD_NAME"
    fi

    echo -e "GAFF Ligand    : ${COLOR_GREEN}$GAFF_MOL2${COLOR_NC}"
    echo -e "FRCMOD Param   : ${COLOR_GREEN}$FRCMOD_NAME${COLOR_NC}"

    # --- 4. ATOM COUNTING ---
    echo -e "\n${COLOR_YELLOW}Analyzing Structures...${COLOR_NC}"
    num_rec=$(grep -c "^ATOM" "$STD_REC")
    num_lig=$(sed -n '/<TRIPOS>ATOM/,/<TRIPOS>BOND/p' "$GAFF_MOL2" | grep -v "TRIPOS" | wc -l)
    est_total=$((num_rec + num_lig))
    
    printf "Receptor Atoms : %-10s\n" "$num_rec"
    printf "Ligand Atoms   : %-10s\n" "$num_lig"
    echo -e "Total Complex  : ${COLOR_GREEN}$est_total${COLOR_NC} atoms (Dry)"
    
    read -p "Generate Topology in 'assets'? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then cd "$current_dir"; return; fi

    # --- 5. TLEAP EXECUTION ---
    cat << EOF > tleap.in
source leaprc.protein.ff14SB
source leaprc.gaff2
source leaprc.water.tip3p

rec = loadPDB $STD_REC
lig = loadMol2 $GAFF_MOL2
loadamberparams $FRCMOD_NAME

complex = combine {rec lig}

saveamberparm complex complex_vac.prmtop complex_vac.inpcrd
saveamberparm lig ligand.prmtop ligand.inpcrd
saveamberparm rec receptor.prmtop receptor.inpcrd

solvatebox complex TIP3PBOX 10.0
addions complex Na+ 0
addions complex Cl- 0

saveamberparm complex complex_solvated.prmtop complex_solvated.inpcrd
savepdb complex complex_solvated.pdb
quit
EOF

    echo "Running Tleap..."
    tleap -f tleap.in > tleap.log 2>&1
    
    if [ -f "complex_solvated.prmtop" ]; then
        echo -e "${COLOR_GREEN}Success! Topology created.${COLOR_NC}"
        echo "Check 'assets/' for .prmtop and .inpcrd files."
    else
        echo -e "${COLOR_RED}Tleap Failed! Check logs below:${COLOR_NC}"
        tail -n 10 tleap.log
    fi
    
    cd "$current_dir"
    pause
}

run_engine() {
    step_name=$1
    echo -e "\n${COLOR_CYAN}>>> RUN ENGINE: ${step_name^^} <<<${COLOR_NC}"
    if [[ -z "$CURRENT_RECEPTOR_DIR" ]]; then echo "No workspace."; pause; return; fi

    list_project_items
    read -p "Enter Target Ligand Name (folder only): " lig_name
    if [[ -z "$lig_name" ]]; then echo "Cancelled."; return; fi

    BASE_DIR="$CURRENT_RECEPTOR_DIR/$lig_name"
    if [ ! -d "$BASE_DIR" ]; then echo "Folder not found!"; pause; return; fi

    # --- SMART MAPPING (EQUIL -> RELAX) ---
    # Input remains 'equil.in', but Output Folder & File becomes 'relax'
    if [[ "$step_name" == "equil" ]]; then
        target_folder="relax"
        output_prefix="relax"
    else
        target_folder="$step_name"
        output_prefix="$step_name"
    fi

    ASSETS_DIR="$BASE_DIR/assets"
    STEP_DIR="$BASE_DIR/$target_folder"
    if [ ! -d "$STEP_DIR" ]; then mkdir -p "$STEP_DIR"; fi
    
    PRMTOP="$ASSETS_DIR/complex_solvated.prmtop"
    
    # --- DEPENDENCY CHAIN CHECKER ---
    case $step_name in
        "min") prev_crd="$ASSETS_DIR/complex_solvated.inpcrd"; ;;
        "heat") prev_crd="$BASE_DIR/min/min.rst"; ;;
        "density") prev_crd="$BASE_DIR/heat/heat.rst"; ;;
        "equil") prev_crd="$BASE_DIR/density/density.rst"; ;; 
        "prod") 
            # Check Relax first (Priority), if not there then check Equil (Legacy)
            if [ -f "$BASE_DIR/relax/relax.rst" ]; then
                prev_crd="$BASE_DIR/relax/relax.rst"
            else
                prev_crd="$BASE_DIR/equil/equil.rst"
            fi
            ;;
    esac

    if [ ! -f "$PRMTOP" ]; then echo -e "${COLOR_RED}Missing Topology!${COLOR_NC}"; pause; return; fi
    if [ ! -f "$prev_crd" ]; then echo -e "${COLOR_RED}Missing Input: $(basename $prev_crd)${COLOR_NC}"; pause; return; fi

    # --- CONFIG PREPARATION ---
    CFG_SRC="$CURRENT_RECEPTOR_DIR/in/${step_name}.in"
    
    # Save the .in file in the target folder with the output prefix (relax.in)
    # To ensure log file consistency: relax.log reads relax.in
    IN_FILE="$STEP_DIR/${output_prefix}.in"

    if [ -f "$CFG_SRC" ]; then
        echo -e "${COLOR_YELLOW}Using Config: $CFG_SRC${COLOR_NC}"
        cp "$CFG_SRC" "$IN_FILE"
        
        # --- PRE-FLIGHT CHECK ---
        echo "----------------------------------------"
        echo " PRE-SIMULATION SUMMARY"
        echo "----------------------------------------"
        
        if [ "$step_name" == "min" ]; then
            steps=$(grep "maxcyc" "$IN_FILE" | sed -n 's/.*maxcyc[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
            temp="-"
            press="-"
        else
            steps=$(grep "nstlim" "$IN_FILE" | sed -n 's/.*nstlim[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
            temp=$(grep "temp0" "$IN_FILE" | sed -n 's/.*temp0[[:space:]]*=[[:space:]]*\([0-9.]*\).*/\1/p')
            ntp=$(grep "ntp" "$IN_FILE" | sed -n 's/.*ntp[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p')
            
            if [[ "$ntp" == "1" ]]; then press="${COLOR_GREEN}ON (Density)${COLOR_NC}"; else press="${COLOR_YELLOW}OFF (Volume)${COLOR_NC}"; fi
        fi
        
        echo " Input Topology : $(basename "$PRMTOP")"
        echo -e " Target Steps   : ${BOLD}${steps}${COLOR_NC}"
        if [ "$temp" != "-" ]; then echo " Target Temp    : ${temp} K"; fi
        if [ "$press" != "-" ]; then echo -e " Pressure Ctrl  : ${press}"; fi
        echo " Output Folder  : $STEP_DIR"
        echo -e " Output Prefix  : ${COLOR_GREEN}$output_prefix${COLOR_NC} (Standardized)"
        echo "----------------------------------------"
        
        # CHECK EXISTING STATUS (Pake output prefix)
        get_step_status "$BASE_DIR" "$target_folder" "$steps"
        echo "----------------------------------------"

        if [ "$STATUS_CODE" -ne 0 ]; then
            echo -e "${COLOR_RED}WARNING: Previous simulation data found!${COLOR_NC}"
            read -p "Overwrite and Restart from 0? (y/n): " ow_yn
            if [[ "$ow_yn" != "y" ]]; then echo "Cancelled."; return; fi
        else
            read -p "Start Sander? (y/n): " run_yn
            if [[ "$run_yn" != "y" ]]; then return; fi
        fi

    else
        echo -e "${COLOR_RED}Config not found in 'in/' folder.${COLOR_NC}"; pause; return
    fi

    echo "Running Sander..."
    MDINFO="$STEP_DIR/mdinfo"
    # FIX: Change the extension to .out (Amber Standard)
    LOGFILE="$STEP_DIR/$output_prefix.out"
    rm -f "$MDINFO"
    
    sander -O -i "$IN_FILE" -o "$LOGFILE" -p "$PRMTOP" -c "$prev_crd" -r "$STEP_DIR/$output_prefix.rst" -x "$STEP_DIR/$output_prefix.nc" -inf "$MDINFO" &
    
    sim_pid=$!
    monitor_simulation $sim_pid "$BASE_DIR" "$LOGFILE" "$step_name" "$MDINFO"
    
    if [ -f "$STEP_DIR/$output_prefix.rst" ]; then 
        echo -e "${COLOR_GREEN}Success!${COLOR_NC}"
    else 
        if ! kill -0 $sim_pid 2>/dev/null; then echo -e "${COLOR_RED}Simulation Failed/Stopped.${COLOR_NC}"; fi
    fi
    pause
}

engine_process_data() {
    local phase=$1
    echo -e "\n${COLOR_CYAN}>>> PROCESS DATA: ${phase^^} <<<${COLOR_NC}"
    list_project_items
    read -p "Enter Target Ligand Name: " lig_name
    if [[ -z "$lig_name" ]]; then return; fi
    
    lig="$CURRENT_RECEPTOR_DIR/$lig_name"
    if [ ! -d "$lig" ]; then echo "Not found."; pause; return; fi
    
    # --- 1. SET TARGET SUMMARY FOLDER ---
    if [[ "$phase" == "relax" || "$phase" == "equil" ]]; then 
        target_dir="$lig/summary/equil"
        analysis_mode="EQUILIBRATION"
    else 
        target_dir="$lig/summary/$phase"
        analysis_mode="PRODUCTION"
    fi

    mkdir -p "$target_dir"; cd "$target_dir" || return

    echo "Checking status..."
    get_file_timestamp "summary.DENSITY"
    if [ $? -eq 0 ]; then
        read -p "Re-process data? (y/n): " re_proc
        if [[ "$re_proc" != "y" ]]; then cd ../../../; return; fi
    else
        read -p "Process data now? (y/n): " proc_yn
        if [[ "$proc_yn" != "y" ]]; then cd ../../../; return; fi
    fi

    # --- 2. SMART SOURCE DETECTION (Folder & Log Files) ---
    src_folder=""
    src_prefix=""
    file_list=""   # File list container variable to be dynamic

    if [[ "$analysis_mode" == "EQUILIBRATION" ]]; then
        # Check Relax (New Standard)
        if [ -f "../../relax/relax.out" ]; then
            src_folder="relax"; src_prefix="relax"
            echo -e "Detected Source: ${COLOR_GREEN}Relax (New Standard)${COLOR_NC}"
        # Check Equil (Legacy)
        elif [ -f "../../equil/equil.out" ]; then
            src_folder="equil"; src_prefix="equil"
            echo -e "Detected Source: ${COLOR_YELLOW}Equil (Legacy)${COLOR_NC}"
        else
            echo -e "${COLOR_RED}Error: Neither 'relax.out' nor 'equil.out' found!${COLOR_NC}"
            cd ../../../; pause; return
        fi
        
        # Arrange File List (Skip heat/density if not there to avoid errors)
        if [ -f "../../heat/heat.out" ]; then file_list="$file_list ../../heat/heat.out"; fi
        if [ -f "../../density/density.out" ]; then file_list="$file_list ../../density/density.out"; fi
        
        # Add Main File
        file_list="$file_list ../../$src_folder/$src_prefix.out"
        base_traj="../../$src_folder/$src_prefix"

    else 
        # Production Phase
        if [ ! -f "../../prod/prod.out" ]; then
            echo -e "${COLOR_RED}Error: Production data not found!${COLOR_NC}"
            cd ../../../; pause; return
        fi
        file_list="../../prod/prod.out"
        base_traj="../../prod/prod"
    fi
    
    # --- 3. SMART TRAJECTORY FORMAT DETECTION (.nc vs .mdcrd) ---
    # (This requires the base_traj variable from step no 2)
    traj=""
    if [ -f "${base_traj}.nc" ]; then
        traj="${base_traj}.nc"
        echo -e "Trajectory Detected: ${COLOR_GREEN}NetCDF (.nc)${COLOR_NC}"
    elif [ -f "${base_traj}.mdcrd" ]; then
        traj="${base_traj}.mdcrd"
        echo -e "Trajectory Detected: ${COLOR_YELLOW}ASCII (.mdcrd)${COLOR_NC}"
    else
        echo -e "${COLOR_RED}Error: No trajectory found!${COLOR_NC}"
        echo "Checked: ${base_traj}.nc AND ${base_traj}.mdcrd"
        echo "Please ensure the simulation finished successfully."
        cd ../../../; pause; return
    fi

    # --- 4. EXTRACT THERMODYNAMICS ---
    echo "Extracting thermodynamic data..."
    if command -v process_mdout.perl &> /dev/null; then 
        # (This requires the file_list variable from step no 2)
        process_mdout.perl $file_list
    else
        echo -e "${COLOR_RED}Error: process_mdout.perl not found.${COLOR_NC}"
    fi
    
    # --- 5. CALCULATE RMSD ---
    echo "Calculating RMSD..."
    cat > rmsd.in <<EOF
trajin $traj
reference ../../assets/complex_solvated.inpcrd
rms reference out summary.RMSD @CA,C,N
EOF
    cpptraj -p ../../assets/complex_solvated.prmtop -i rmsd.in > rmsd.log
    
    if [ -s "summary.RMSD" ]; then
        echo -e "${COLOR_GREEN}Done. Data saved in: $target_dir${COLOR_NC}"
    else
        echo -e "${COLOR_RED}RMSD Calculation Failed. Check rmsd.log${COLOR_NC}"
    fi
    
    cd ../../../; pause
}

engine_run_hbond() {
    echo -e "\n${COLOR_CYAN}>>> H-BOND ANALYSIS <<<${COLOR_NC}"
    list_project_items
    read -p "Enter Ligand Name: " lig_name
    if [[ -z "$lig_name" ]]; then return; fi
    
    lig="$CURRENT_RECEPTOR_DIR/$lig_name"
    if [ ! -d "$lig" ]; then echo "Folder not found."; pause; return; fi
    
    # --- 1. TRAJECTORY CHECK ---
    traj_file=""
    if [ -f "$lig/prod/prod.nc" ]; then traj_file="../prod/prod.nc"
    elif [ -f "$lig/prod/prod.mdcrd" ]; then traj_file="../prod/prod.mdcrd"
    else echo -e "${COLOR_RED}Error: Trajectory missing!${COLOR_NC}"; pause; return; fi

    mkdir -p "$lig/hbond"; cd "$lig/hbond" || return

    get_file_timestamp "hbond_summary.dat"
    if [ $? -eq 0 ]; then
        read -p "Overwrite analysis? (y/n): " ow
        if [[ "$ow" != "y" ]]; then cd ../../; return; fi
    fi

    # --- 2. SMART MASK INPUT ---
    echo "----------------------------------------------------"
    echo "Residue Mask Selection:"
    echo "Check your PDB for Ligand Residue Name (e.g., WRA, UNK, MOL)"
    echo "Example: Type 'WRA' (Auto-converted to :WRA)"
    echo "----------------------------------------------------"
    read -p "Enter Ligand Code: " user_input
    if [[ -z "$user_input" ]]; then return; fi

    # Auto-add Colon
    if [[ "$user_input" != :* && "$user_input" != @* ]]; then lig_mask=":$user_input"; else lig_mask="$user_input"; fi
    
    echo -e "Using Mask: ${COLOR_GREEN}$lig_mask${COLOR_NC}"
    echo "Running H-Bond Analysis..."
    
    # --- 3. EXECUTE CPPTRAJ ---
    # Mask Logic: !($lig_mask) & !(:WAT,Na+,Cl-) = PROTEIN ONLY
    
    cat > hbond.in <<EOF
trajin $traj_file
# 1. Protein as Donor -> Ligand Acceptor
hbond PL_donor donormask !($lig_mask)&!(:WAT,Na+,Cl-) acceptormask $lig_mask out hbond_PD.dat avgout hbond_avg_PD.dat dist 3.5 angle 120

# 2. Ligand as Donor -> Protein Acceptor
hbond PL_acceptor donormask $lig_mask acceptormask !($lig_mask)&!(:WAT,Na+,Cl-) out hbond_LD.dat avgout hbond_avg_LD.dat dist 3.5 angle 120
run
EOF
    
    cpptraj -p ../assets/complex_solvated.prmtop -i hbond.in > hbond.log
    
    # --- 4. COMBINE & CLEANUP ---
    if [ -s "hbond_avg_PD.dat" ]; then
        echo "Combining results..."
        
        # Merge Headers
        echo "# H-BOND ANALYSIS SUMMARY" > hbond_summary.dat
        echo "# PROTEIN-DONOR -> LIGAND-ACCEPTOR" >> hbond_summary.dat
        cat hbond_avg_PD.dat >> hbond_summary.dat
        
        echo -e "\n# LIGAND-DONOR -> PROTEIN-ACCEPTOR" >> hbond_summary.dat
        
        if [ -s "hbond_avg_LD.dat" ]; then
            cat hbond_avg_LD.dat >> hbond_summary.dat
        else
            echo "# (None detected - Ligand has no active proton donors)" >> hbond_summary.dat
        fi
        
        echo -e "${COLOR_GREEN}Done. Check file: hbond/hbond_summary.dat${COLOR_NC}"
        
        # Show preview
        echo "----------------------------------------"
        head -n 10 hbond_summary.dat
        echo "..."
        echo "----------------------------------------"
    else
        echo -e "${COLOR_RED}Analysis Failed. Check hbond.log${COLOR_NC}"
        echo "Verify that '$lig_mask' actually exists in your PDB."
    fi
    
    cd ../../; pause
}

engine_run_mmgbsa() {
    echo -e "\n${COLOR_CYAN}>>> MMGBSA CALCULATION <<<${COLOR_NC}"
    list_project_items
    read -p "Enter Ligand Name: " lig_name
    if [[ -z "$lig_name" ]]; then return; fi
    
    lig="$CURRENT_RECEPTOR_DIR/$lig_name"
    if [ ! -d "$lig" ]; then echo "Folder not found."; pause; return; fi
    
    # --- 1. SMART TRAJECTORY DETECTION ---
    traj_file=""
    if [ -f "$lig/prod/prod.nc" ]; then
        traj_file="../prod/prod.nc"
        echo -e "Trajectory: ${COLOR_GREEN}NetCDF (.nc)${COLOR_NC}"
    elif [ -f "$lig/prod/prod.mdcrd" ]; then
        traj_file="../prod/prod.mdcrd"
        echo -e "Trajectory: ${COLOR_YELLOW}ASCII (.mdcrd)${COLOR_NC}"
    else
        echo -e "${COLOR_RED}Error: Production trajectory (prod.nc/mdcrd) not found.${COLOR_NC}"
        pause; return
    fi
    # -------------------------------------

    mkdir -p "$lig/gbsa"; cd "$lig/gbsa" || return

    get_file_timestamp "mmgbsa_results.dat"
    if [ $? -eq 0 ]; then
        echo -e "${COLOR_YELLOW}Warning: MMGBSA takes a long time.${COLOR_NC}"
        read -p "Result exists. Re-run calculation? (y/n): " ow
        if [[ "$ow" != "y" ]]; then cd ../../; return; fi
    fi

    # --- 2. CORRECT TOPOLOGY PATHS ---
    # The latest prepare_assets module already stores a separate topology in assets/
    
    # Complex Solvated (for simulation/traj)
    SP="../assets/complex_solvated.prmtop"
    # Complex Vacuum (for energy calculations)
    CP="../assets/complex_vac.prmtop"
    # Receptor Vacuum
    RP="../assets/receptor.prmtop"
    # Ligand Vacuum
    LP="../assets/ligand.prmtop"

    # File Validation
    if [[ ! -f "$SP" || ! -f "$CP" || ! -f "$RP" || ! -f "$LP" ]]; then
        echo -e "${COLOR_RED}Error: One or more topology files are missing in 'assets/'.${COLOR_NC}"
        echo "Ensure you generated topology with the latest version of this script."
        cd ../../; pause; return
    fi

    # Create a standard MMGBSA input file
    if [ ! -f "mmgbsa.in" ]; then 
        echo "Creating default mmgbsa.in..."
        echo -e "&general\n  startframe=1, endframe=500, interval=1, verbose=2,\n/\n&gb\n  igb=5, saltcon=0.15,\n/" > mmgbsa.in
    fi

    echo "Running MMPBSA.py (This may take minutes to hours)..."
    
    # Execute
    MMPBSA.py -O -i mmgbsa.in \
              -o mmgbsa_results.dat \
              -sp "$SP" \
              -cp "$CP" \
              -rp "$RP" \
              -lp "$LP" \
              -y  "$traj_file"
              
    if [ -s "mmgbsa_results.dat" ]; then
        echo -e "${COLOR_GREEN}Done. Binding Energy Calculated.${COLOR_NC}"
    else
        echo -e "${COLOR_RED}Calculation Failed. Check _MMPBSA_*.log files.${COLOR_NC}"
    fi
    
    cd "$HOME"; pause
}

# ==============================================================================
# MODULE 5: UTILITIES & PLOTTER (SMART LISTING & NO-DATA FIX)
# ==============================================================================

check_project_status() {
    echo -e "\n${COLOR_CYAN}>>> PROJECT STATUS VALIDATOR <<<${COLOR_NC}"
    list_project_items
    
    read -p "Check Ligand Name: " lig_name
    if [[ -z "$lig_name" ]]; then return; fi

    lig="$CURRENT_RECEPTOR_DIR/$lig_name"
    if [ ! -d "$lig" ]; then echo "Not found."; pause; return; fi
    
    echo -e "\nStatus: ${COLOR_YELLOW}$lig_name${COLOR_NC}"
    echo "------------------------------------------------------------------"
    # STATUS column is 18 chars wide, enough for [PENDING] + space
    printf "%-25s | %-18s | %-20s\n" "STEP" "STATUS" "KEY FILE"
    echo "------------------------------------------------------------------"
    
    steps=(
        "0. Assets (Topology)"  "$lig/assets/complex_solvated.prmtop"
        "1. Minimization"       "$lig/min/min.out"
        "2. Heating"            "$lig/heat/heat.out"
        "3. Density"            "$lig/density/density.out"
        "4. Equilibration"      "$lig/relax/relax.out"
        "5. Equil Summary"      "$lig/summary/equil/summary.DENSITY"
        "6. Production"         "$lig/prod/prod.out"
        "7. Prod Summary"       "$lig/summary/prod/summary.DENSITY"
        "12. MMGBSA"            "$lig/gbsa/mmgbsa_results.dat"
    )
    
    for ((i=0; i<${#steps[@]}; i+=2)); do
        name="${steps[i]}"
        file="${steps[i+1]}"
        
        # LOGIC STATUS TIGHT BRACKETS
        if [ -f "$file" ]; then
            if [ -s "$file" ]; then 
                # [DONE] - Green Text Only
                stat_txt="[${COLOR_GREEN}DONE${COLOR_NC}]" 
            else 
                # [EMPTY]
                stat_txt="[${COLOR_RED}EMPTY${COLOR_NC}]" 
            fi
        else 
            # [PENDING]
            stat_txt="[${COLOR_YELLOW}PENDING${COLOR_NC}]" 
        fi
        
        # %-27b because there are invisible characters in the color code
        # (DONE=4 chars + 2 brackets = 6 visual chars. But the color code is long)
        # Trick: Let printf manage the visual layout.
        
        printf "%-25s | %-27b | %-20s\n" "$name" "$stat_txt" "$(basename "$file")"
    done
    echo "------------------------------------------------------------------"
    pause
}

# --- PLOTTER (FIXED: SMART LISTING + LEGEND HANDLER) ---
run_plotting_tool() {
    local mode=$1 
    
    echo -e "\n${COLOR_CYAN}>>> PLOTTING TOOL: ${mode^^} <<<${COLOR_NC}"
    list_project_items

    read -p "Enter Project/Ligand Name: " lig_name
    if [[ -z "$lig_name" ]]; then return; fi

    lig="$CURRENT_RECEPTOR_DIR/$lig_name"
    if [ ! -d "$lig" ]; then echo "Folder not found."; pause; return; fi

    # AUTO CREATE PLOT DIR
    PLOT_ROOT="$CURRENT_RECEPTOR_DIR/plot"
    LIG_PLOT_DIR="$PLOT_ROOT/$lig_name"
    if [ ! -d "$LIG_PLOT_DIR" ]; then mkdir -p "$LIG_PLOT_DIR"; fi

    # --- NEW: DATA VALIDATION PROTOCOL ---
    echo "Checking data availability..."
    DATA_MISSING=false
    MISSING_MSG=""

    # Check Equil Data
    if [[ "$mode" == "equil" || "$mode" == "compare" ]]; then
        if [ ! -s "$lig/summary/equil/summary.RMSD" ]; then 
            DATA_MISSING=true
            MISSING_MSG="Equilibration Data (Step 5)"
        fi
    fi
    
    # Check Prod Data
    if [[ "$mode" == "prod" || "$mode" == "compare" ]]; then
        if [ ! -s "$lig/summary/prod/summary.RMSD" ]; then 
            DATA_MISSING=true
            MISSING_MSG="${MISSING_MSG} Production Data (Step 7)"
        fi
    fi

    # IF DATA IS LOST -> STOP & WARNING
    if [ "$DATA_MISSING" = true ]; then
        echo -e "\n${COLOR_RED}>>> ERROR: NO DATA FOUND! <<<${COLOR_NC}"
        echo -e "Cannot generate plot because data is missing or empty."
        echo -e "Missing: ${COLOR_YELLOW}$MISSING_MSG${COLOR_NC}"
        echo ""
        echo "Possible Fixes:"
        echo "1. Did you run the 'Process Data' step? (Menu 5 for Equil, 7 for Prod)"
        echo "2. Did the simulation crash? (Check logs in min/heat/prod folder)"
        echo "3. Is the folder name correct?"
        echo "--------------------------------------------------------"
        pause
        return # STOP PROCESS
    fi
    # -------------------------------------

    # SMART CHECK (Timestamp)
    target_img="$LIG_PLOT_DIR/Journal_Analysis.jpg"
    if [ "$mode" != "compare" ]; then target_img="$LIG_PLOT_DIR/Check_${mode}.png"; fi
    
    echo "Target output: plot/$lig_name/$(basename "$target_img")"
    get_file_timestamp "$target_img"
    
    if [ $? -eq 0 ]; then
        read -p "Regenerate plots? (y/n): " ow
        if [[ "$ow" != "y" ]]; then return; fi
    fi

    echo "Generating High-Quality Plots..."
    rm -f temp_plotter.py
    cat > temp_plotter.py << 'EOF'
import sys
import os
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec

# --- INPUT ARGUMENTS ---
try:
    ligand = sys.argv[1]
    mode = sys.argv[2]
    output_dir = sys.argv[3]
except IndexError:
    print("Error: Missing arguments for plotting script.")
    sys.exit(1)

# --- DATA LOADER FUNCTIONS ---
def read_data(filepath):
    """Reads X Y data from Amber files (.dat/.out) with robust handling."""
    if not os.path.exists(filepath): return np.array([]), np.array([])
    x, y = [], []
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
            # Header detection: skip first line if not numeric
            start = 1 if len(lines) > 0 and not lines[0].strip()[0].isdigit() else 0
            for line in lines[start:]:
                parts = line.strip().split()
                if len(parts) >= 2:
                    try: 
                        x.append(float(parts[0]))
                        y.append(float(parts[1]))
                    except ValueError: pass
                elif len(parts) == 1:
                    try: 
                        y.append(float(parts[0]))
                    except ValueError: pass
        
        # If X is empty but Y exists, create a dummy X (frame sequence)
        if len(x) == 0 and len(y) > 0:
            x = list(range(1, len(y) + 1))
            
        return np.array(x), np.array(y)
    except Exception as e:
        print(f"Warning reading {filepath}: {e}")
        return np.array([]), np.array([])

def get_stats(y):
    """Calculating Mean +/- Std Dev."""
    if len(y) == 0: return "N/A"
    return f"{np.mean(y):.2f} ± {np.std(y):.2f}"

def get_mmgbsa_stats(filepath):
    """Retrieves the Total Delta value from the MMGBSA file."""
    if not os.path.exists(filepath): return "N/A"
    try:
        with open(filepath, 'r') as f:
            for line in f:
                if "DELTA TOTAL" in line:
                    parts = line.split()
                    if len(parts) >= 4: 
                        return f"{float(parts[2]):.2f} ± {float(parts[3]):.2f}"
    except: pass
    return "Not Run"

# --- MAIN PLOTTING LOGIC ---

# File Path Definition
dir_eq = f"{ligand}/summary/equil"
dir_pr = f"{ligand}/summary/prod"
file_mmgbsa = f"{ligand}/gbsa/mmgbsa_results.dat"

files = {
    'eq_rms': f"{dir_eq}/summary.RMSD",   'pr_rms': f"{dir_pr}/summary.RMSD",
    'eq_den': f"{dir_eq}/summary.DENSITY",'pr_den': f"{dir_pr}/summary.DENSITY",
    'eq_tmp': f"{dir_eq}/summary.TEMP",   'pr_tmp': f"{dir_pr}/summary.TEMP",
    'eq_eto': f"{dir_eq}/summary.ETOT",   'pr_eto': f"{dir_pr}/summary.ETOT"
}

if mode == 'compare':
    # Canvas Setup (Enlarged size for more space)
    fig = plt.figure(figsize=(16, 13))
    
    # Main Title (Given a position of y=0.98 to avoid being hit)
    lig_name_clean = os.path.basename(ligand)
    fig.suptitle(f'MD Simulation Analysis: {lig_name_clean}', fontsize=18, fontweight='bold', y=0.98)
    
    # Grid Layout (3 Rows, 4 Columns)
    gs = gridspec.GridSpec(3, 4, figure=fig)
    
    # Row 1: Temp & Energy
    ax_t1 = fig.add_subplot(gs[0, 0]); ax_t2 = fig.add_subplot(gs[0, 1])
    ax_e1 = fig.add_subplot(gs[0, 2]); ax_e2 = fig.add_subplot(gs[0, 3])
    
    # Row 2: Density & Summary Box
    ax_d1 = fig.add_subplot(gs[1, 0]); ax_d2 = fig.add_subplot(gs[1, 1])
    ax_stat = fig.add_subplot(gs[1, 2:]) # Summary Box ambil sisa ruang kanan
    
    # Row 3: RMSD (Full Width)
    ax_rms = fig.add_subplot(gs[2, :])

    # Quick Plotting Helper Function
    def plot_pair(ax1, ax2, f1, f2, c1, c2, title, ylabel):
        x1, y1 = read_data(f1); x2, y2 = read_data(f2)
        
        # Plot Equil
        if len(y1) > 0: 
            ax1.plot(x1, y1, color=c1, lw=1)
            ax1.set_title(f"{title} (Equil)", fontsize=10)
            ax1.set_ylabel(ylabel)
            ax1.grid(alpha=0.3)
        else: 
            ax1.text(0.5, 0.5, "No Data", ha='center', transform=ax1.transAxes)
            ax1.set_title(title)
        
        # Plot Prod
        if len(y2) > 0: 
            ax2.plot(x2, y2, color=c2, lw=1)
            ax2.set_title(f"{title} (Prod)", fontsize=10)
            ax2.grid(alpha=0.3)
        else: 
            ax2.text(0.5, 0.5, "No Data", ha='center', transform=ax2.transAxes)
            ax2.set_title(title)
            
        return get_stats(y1), get_stats(y2)

    # Plotting Execution
    st_t1, st_t2 = plot_pair(ax_t1, ax_t2, files['eq_tmp'], files['pr_tmp'], 'darkgreen', 'darkgreen', 'Temperature', 'Temp (K)')
    st_e1, st_e2 = plot_pair(ax_e1, ax_e2, files['eq_eto'], files['pr_eto'], 'purple', 'purple', 'Total Energy', 'E (kcal/mol)')
    st_d1, st_d2 = plot_pair(ax_d1, ax_d2, files['eq_den'], files['pr_den'], 'teal', 'teal', 'Density', 'Dens (g/cm³)')

    # Special RMSD Plot (Combined)
    x_r1, y_r1 = read_data(files['eq_rms'])
    x_r2, y_r2 = read_data(files['pr_rms'])
    
    has_data = False
    if len(y_r1) > 0: 
        ax_rms.plot(x_r1, y_r1, 'b-', label='Equil', lw=1.2)
        has_data = True
    if len(y_r2) > 0: 
        # If the Prod X axis is reset to 0, slide it to connect (optional, here we just plot raw)
        ax_rms.plot(x_r2, y_r2, 'r-', label='Prod', lw=1.2)
        has_data = True
        
    ax_rms.set_title('RMSD Backbone Evolution', fontsize=12)
    ax_rms.set_ylabel('RMSD (Å)')
    ax_rms.set_xlabel('Frame / Time')
    ax_rms.grid(alpha=0.3)
    if has_data: ax_rms.legend(loc='upper left')

    # Statistics & Summary Box
    st_r1, st_r2 = get_stats(y_r1), get_stats(y_r2)
    mmgbsa_val = get_mmgbsa_stats(file_mmgbsa)

    ax_stat.axis('off')
    text_str =  f"SIMULATION SUMMARY\n{'='*45}\n\n"
    text_str += f"EQUILIBRATION PHASE:\n"
    text_str += f"  - RMSD : {st_r1} Å\n  - Temp : {st_t1} K\n  - Dens : {st_d1} g/cm³\n\n"
    text_str += f"PRODUCTION PHASE:\n"
    text_str += f"  - RMSD : {st_r2} Å\n  - Temp : {st_t2} K\n  - Dens : {st_d2} g/cm³\n\n"
    text_str += f"{'-'*45}\n"
    text_str += f"BINDING FREE ENERGY (MMGBSA):\n  DELTA TOTAL: {mmgbsa_val} kcal/mol"
    
    props = dict(boxstyle='round', facecolor='oldlace', alpha=0.5)
    ax_stat.text(0.05, 0.95, text_str, transform=ax_stat.transAxes, fontsize=11,
                 verticalalignment='top', bbox=props, family='monospace')

    # --- FIX LAYOUT OVERLAP & SAVE PNG ---
    # rect=[left, bottom, right, top]. 0.95 meaning leave 5% space above.
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    
    out_file = f"{output_dir}/Journal_Analysis.png"
    plt.savefig(out_file, dpi=300)
    print(f"Journal plot saved: {out_file}")

else:
    # Mode Check (Simple 2 Plot)
    fig, axs = plt.subplots(1, 2, figsize=(12, 5))
    fig.suptitle(f'{mode.capitalize()} Phase Check: {os.path.basename(ligand)}', fontweight='bold')
    
    # RMSD
    x, y = read_data(files[f'{mode[:2]}_rms'])
    if len(y) > 0: 
        axs[0].plot(x, y, 'b-')
        axs[0].set_ylabel("RMSD (Å)")
        axs[0].grid(alpha=0.3)
    else: axs[0].text(0.5,0.5,"No Data", ha='center')
    axs[0].set_title("RMSD Stability")

    # Density
    x, y = read_data(files[f'{mode[:2]}_den'])
    if len(y) > 0: 
        axs[1].plot(x, y, 'g-')
        axs[1].set_ylabel("Density (g/cm³)")
        axs[1].grid(alpha=0.3)
    else: axs[1].text(0.5,0.5,"No Data", ha='center')
    axs[1].set_title("Density Stability")
    
    plt.tight_layout()
    out_file = f"{output_dir}/Check_{mode}.png"
    plt.savefig(out_file)
    print(f"Check plot saved: {out_file}")

EOF

    # Pass LIG_PLOT_DIR as argument 3
    python3 temp_plotter.py "$lig" "$mode" "$LIG_PLOT_DIR"
    rm temp_plotter.py
    pause
}

# ==============================================================================
# MAIN MENU CONTROLLER (WITH PATH DISPLAY)
# ==============================================================================

# --- UTILITY: RANDOM GOODBYE ---
get_random_goodbye() {
    messages=(
        "Goodbye, $USER! Don't forget to star the repo! ⭐"
        "May your trajectory always converge! 📉 See you soon."
        "Have a flawless research session! 🧪"
        "Fay MDS Suite signing off... Happy simulating! 🚀"
        "Simulation complete? Time for a coffee break! ☕"
        "Don't forget to cite AmberTools & Fay MDS in your paper! 📝"
        "Exiting... Keep pushing the boundaries of science! 🌌"
        "See you next time! 🫡"
    )
    
    # Select random index
    rand_index=$((RANDOM % ${#messages[@]}))
    echo -e "${COLOR_GREEN}${messages[$rand_index]}${COLOR_NC}"
}

main_menu() {
    while true; do
        clear
        echo -e "${COLOR_BLUE}======================================================${COLOR_NC}"
        echo -e "${COLOR_BLUE}      FAY'S MOLECULAR DYNAMICS SUITE - MAIN MENU      ${COLOR_NC}"
        echo -e "${COLOR_BLUE}======================================================${COLOR_NC}"
        # --- NEW STATUS BAR ---
        echo -e "ACTIVE WORKSPACE: ${COLOR_GREEN}${CURRENT_RECEPTOR_DIR}/${COLOR_NC}"
        echo -e "======================================================"
        
        # --- PHASE SYSTEM ---
        echo -e "${COLOR_YELLOW}[ SYSTEM & CONFIG ]${COLOR_NC}"
        echo "  m. User Manual"
        echo "  c. Citation Helper"  # <--- NEW
        echo "  u. Check for Updates"  # <--- NEW MENU
        echo "  w. Change Active Workspace"  # <--- NEW
        echo "  d. Dependency Manager"
        echo "  i. Input File Manager"
        
        echo -e "\n${COLOR_YELLOW}[ PHASE 0: PREPARATION ]${COLOR_NC}"
        echo "  0. Setup Assets (Topology Generation)"
        
        echo -e "\n${COLOR_YELLOW}[ PHASE 1: EQUILIBRATION ]${COLOR_NC}"
        echo "  1. Run Minimization"
        echo "  2. Run Heating"
        echo "  3. Run Density"
        echo "  4. Run Equilibration"
        echo "  5. Process Equil Data"
        echo "  P1. Plot Validation Graph"
        
        echo -e "\n${COLOR_YELLOW}[ PHASE 2: PRODUCTION ]${COLOR_NC}"
        echo "  6. Run Production"
        echo "  7. Process Prod Data"
        echo "  P2. Plot Production Graph"
        
        echo -e "\n${COLOR_YELLOW}[ PHASE 3: ANALYSIS ]${COLOR_NC}"
        echo "  8. Run H-Bond"
        echo "  9. Run MMGBSA"
        echo "  P3. Plot Full Journal Analysis"
        
        echo -e "\n------------------------------------------------------"
        echo "  S. Check Project Status"
        echo "  Q. Quit"
        echo "------------------------------------------------------"
        
        read -p "Select Option: " opt
        
        case $opt in
            m) show_manual ;;
            c) show_citation ;; # <--- NEW ACTION
            u) check_updates ;; # <--- NEW ACTION
            w) workspace_manager ;;      # <--- NEW ACTION
            d) dependency_manager ;;
            i) input_file_manager ;;
            0) engine_prepare_assets ;;
            1) run_engine "min" ;;
            2) run_engine "heat" ;;
            3) run_engine "density" ;;
            4) run_engine "equil" ;;
            5) engine_process_data "equil" ;;
            P1|p1) run_plotting_tool "equil" ;;
            6) run_engine "prod" ;;
            7) engine_process_data "prod" ;;
            P2|p2) run_plotting_tool "prod" ;;
            8) engine_run_hbond ;;
            9) engine_run_mmgbsa ;;
            P3|p3) run_plotting_tool "compare" ;;
            S|s) check_project_status ;;
            Q|q) 
                get_random_goodbye   # <--- CALL FUNCTION HERE
                exit 0 
                ;;
                
            *) echo "Invalid Option."; sleep 1 ;;
        esac
    done
}

# ==============================================================================
# ENTRY POINT
# ==============================================================================

# 1. Show EULA
show_eula

# 2. Workspace Manager (Select Receptor first)
workspace_manager

# 3. Main Menu
main_menu
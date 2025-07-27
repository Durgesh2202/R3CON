#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAG='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Banner
clear
echo -e "${RED}${BOLD}


    ____ _____ __________  _   __            
   / __ \__  // ____/ __ \/ | / /            
  / /_/ //_ </ /   / / / /  |/ /             
 / _, _/__/ / /___/ /_/ / /|  /              
/_/ |_/____/\____/\____/_/ |_/               
                                             
    ____                                     
   / __ )__  __                              
  / __  / / / /                              
 / /_/ / /_/ /                               
/_____/\__, /                                
      /____/                                 
    ____  __  ______  _______  _______ __  __
   / __ \/ / / / __ \/ ____/ |/ / ___// / / /
  / / / / / / / /_/ / / __ |   /\__ \/ /_/ / 
 / /_/ / /_/ / _, _/ /_/ //   |___/ / __  /  
/_____/\____/_/ |_|\____//_/|_/____/_/ /_/   
                                              


${CYAN}  Respect is earned. Access is taken.
      Talk less. Scan more
${NC}"

# Ensure domain argument is given
if [ -z "$1" ]; then
  echo -e "${RED}${BOLD}Usage: $0 <domain> [scan_params]${NC}"
  echo -e "${YELLOW}Optional: Add 'params' as second argument to scan parameters (slow)${NC}"
  exit 1
fi

DOMAIN=$1
SCAN_PARAMS=${2:-"no"}
DATE=$(date +"%d-%m-%Y")
OUTDIR="Recon-$DOMAIN-$DATE"
mkdir -p "$OUTDIR"

echo -e "${CYAN}${BOLD}[1] Running subfinder...${NC}"
subfinder -d "$DOMAIN" -silent > "$OUTDIR/subdomains.txt"
echo -e "${YELLOW}    Subdomains found: $(wc -l < "$OUTDIR/subdomains.txt")${NC}"
echo -e "${GREEN}    ✔ Subdomains stored at: $OUTDIR/subdomains.txt${NC}"

echo -e "${CYAN}${BOLD}[2] Probing live subdomains with httpx...${NC}"
httpx -l "$OUTDIR/subdomains.txt" -silent -mc 200,301,302 -threads 100 -timeout 5 > "$OUTDIR/live.txt"
echo -e "${YELLOW}    Live hosts found: $(wc -l < "$OUTDIR/live.txt")${NC}"
echo -e "${GREEN}    ✔ Live hosts stored at: $OUTDIR/live.txt${NC}"

echo -e "${CYAN}${BOLD}[3] Fetching archive URLs with waybackurls...${NC}"
echo "$DOMAIN" | waybackurls > "$OUTDIR/wayback-main.txt"
echo -e "${YELLOW}    Wayback URLs found: $(wc -l < "$OUTDIR/wayback-main.txt")${NC}"
echo -e "${GREEN}    ✔ Wayback URLs stored at: $OUTDIR/wayback-main.txt${NC}"

echo -e "${CYAN}${BOLD}[4] Extracting URLs with parameters from wayback...${NC}"
grep '?' "$OUTDIR/wayback-main.txt" > "$OUTDIR/params.txt"
echo -e "${YELLOW}    Parameter URLs found: $(wc -l < "$OUTDIR/params.txt")${NC}"
echo -e "${GREEN}    ✔ Parameter URLs stored at: $OUTDIR/params.txt${NC}"

echo -e "${CYAN}${BOLD}[5] Extracting archived JS URLs from wayback...${NC}"
grep '\.js' "$OUTDIR/wayback-main.txt" > "$OUTDIR/js-files.txt"
echo -e "${YELLOW}    JS files found: $(wc -l < "$OUTDIR/js-files.txt")${NC}"
echo -e "${GREEN}    ✔ Archived JS files stored at: $OUTDIR/js-files.txt${NC}"

echo -e "${CYAN}${BOLD}[6] Extracting live JS files from live hosts using getJS...${NC}"
getJS --input "$OUTDIR/live.txt" --output "$OUTDIR/livejs.txt"
echo -e "${YELLOW}    Live JS files found: $(wc -l < "$OUTDIR/livejs.txt")${NC}"
echo -e "${GREEN}    ✔ Live JS files stored at: $OUTDIR/livejs.txt${NC}"

echo -e "${CYAN}${BOLD}[7] Running nuclei vulnerability scan...${NC}"
# Update templates
echo -e "${YELLOW}    Updating nuclei templates...${NC}"
nuclei -update-templates > /dev/null 2>&1

# Run nuclei with focus on vulnerabilities - now with timeout
echo -e "${YELLOW}    Scanning for vulnerabilities...${NC}"
nuclei -l "$OUTDIR/live.txt" -o "$OUTDIR/nuclei-results.txt" -severity medium,high,critical -silent -timeout 5

# Check if results exist and display them
if [ -s "$OUTDIR/nuclei-results.txt" ]; then
    echo -e "${RED}    VULNERABILITIES FOUND: $(wc -l < "$OUTDIR/nuclei-results.txt")${NC}"
    echo -e "${RED}    Results preview:${NC}"
    cat "$OUTDIR/nuclei-results.txt" | head -n 10
else
    echo -e "${GREEN}    No vulnerabilities found in hosts${NC}"
fi

echo -e "${GREEN}    ✔ Nuclei results stored at: $OUTDIR/nuclei-results.txt${NC}"

# ONLY scan parameters if explicitly requested
if [ "$SCAN_PARAMS" = "params" ]; then
    echo -e "${CYAN}${BOLD}[7B] Scanning parameters for vulnerabilities (SAMPLE ONLY)...${NC}"
    # Only scan a small random sample of parameters to save time
    echo -e "${YELLOW}    Taking a sample of 100 parameter URLs (out of $(wc -l < "$OUTDIR/params.txt"))...${NC}"
    sort -R "$OUTDIR/params.txt" | head -n 100 > "$OUTDIR/params-sample.txt"

    echo -e "${YELLOW}    Scanning parameter sample with nuclei...${NC}"
    nuclei -l "$OUTDIR/params-sample.txt" -o "$OUTDIR/params-vulnerabilities.txt" -severity medium,high,critical -silent -timeout 5

    if [ -s "$OUTDIR/params-vulnerabilities.txt" ]; then
        echo -e "${RED}    PARAMETER VULNERABILITIES FOUND: $(wc -l < "$OUTDIR/params-vulnerabilities.txt")${NC}"
        echo -e "${RED}    Results preview:${NC}"
        cat "$OUTDIR/params-vulnerabilities.txt" | head -n 10
    else
        echo -e "${GREEN}    No vulnerabilities found in parameter sample${NC}"
    fi
    echo -e "${GREEN}    ✔ Parameter vulnerability results: $OUTDIR/params-vulnerabilities.txt${NC}"
else
    echo -e "${YELLOW}    Skipping parameter scanning (35,942 URLs would take too long)${NC}"
    echo -e "${YELLOW}    To scan parameters, run: $0 $DOMAIN params${NC}"
fi

echo -e "${CYAN}${BOLD}[8] Taking screenshots of live hosts with GoWitness...${NC}"
mkdir -p "$OUTDIR/screenshots"
gowitness scan file -f "$OUTDIR/live.txt" -s "$OUTDIR/screenshots"
echo -e "${YELLOW}    Screenshots saved: $(ls "$OUTDIR/screenshots" | wc -l)${NC}"
echo -e "${GREEN}    ✔ Screenshots stored at: $OUTDIR/screenshots${NC}"

echo -e "${MAG}${BOLD}
╔══════════════════════════════════════════════════╗
║         Recon Complete!                         ║
╚══════════════════════════════════════════════════╝
${NC}"
echo -e "${YELLOW}All results are organized in: $OUTDIR${NC}"

# Show a summary of findings
echo -e "${RED}${BOLD}Vulnerability Summary:${NC}"
if [ -s "$OUTDIR/nuclei-results.txt" ]; then
    echo -e "${RED}• $(wc -l < "$OUTDIR/nuclei-results.txt") vulnerabilities found in live hosts${NC}"
    grep -o '\[.*\]' "$OUTDIR/nuclei-results.txt" | sort | uniq -c | sort -nr
else
    echo -e "${GREEN}• No vulnerabilities found in live hosts${NC}"
fi

if [ "$SCAN_PARAMS" = "params" ] && [ -s "$OUTDIR/params-vulnerabilities.txt" ]; then
    echo -e "${RED}• $(wc -l < "$OUTDIR/params-vulnerabilities.txt") vulnerabilities found in parameters${NC}"
    grep -o '\[.*\]' "$OUTDIR/params-vulnerabilities.txt" | sort | uniq -c | sort -nr
elif [ "$SCAN_PARAMS" = "params" ]; then
    echo -e "${GREEN}• No vulnerabilities found in parameter sample${NC}"
fi
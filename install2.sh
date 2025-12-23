#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}${BOLD}Please run as root or with sudo${NC}"
  exit 1
fi

echo -e "${CYAN}${BOLD}
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
${NC}"

echo -e "${YELLOW}Installing R3CON reconnaissance toolkit...${NC}"

# Step 1: Install required packages
echo -e "\n${CYAN}${BOLD}[1/5] Installing system dependencies...${NC}"
apt update -y
apt install -y curl wget git ruby python3 python3-pip chromium golang-go

# Step 2: Set up Go environment
echo -e "\n${CYAN}${BOLD}[2/5] Setting up Go environment...${NC}"

# Determine the actual user (even when running with sudo)
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

# Set up Go paths
export GOPATH=$ACTUAL_HOME/go
export PATH=$PATH:/usr/lib/go-1.21/bin:$GOPATH/bin

# Create Go directories
mkdir -p $GOPATH/{bin,src,pkg}

# Add to user's bashrc (not root's)
if !  grep -q "export GOPATH=\$HOME/go" "$ACTUAL_HOME/.bashrc"; then
    echo 'export GOPATH=$HOME/go' >> "$ACTUAL_HOME/.bashrc"
    echo 'export PATH=$PATH:/usr/lib/go-1.21/bin:$GOPATH/bin' >> "$ACTUAL_HOME/.bashrc"
fi

# Also add to /etc/profile for system-wide availability
if ! grep -q "export GOPATH=\$HOME/go" /etc/profile; then
    echo 'export GOPATH=$HOME/go' >> /etc/profile
    echo 'export PATH=$PATH:/usr/lib/go-1.21/bin:$GOPATH/bin' >> /etc/profile
fi

# Verify Go is available
if ! command -v go &> /dev/null; then
    echo -e "${RED}Go installation failed.  Please install golang-go manually.${NC}"
    exit 1
fi

echo -e "${GREEN}Go version: $(go version)${NC}"

# Step 3: Install reconnaissance tools
echo -e "\n${CYAN}${BOLD}[3/5] Installing reconnaissance tools... ${NC}"

echo -e "${YELLOW}  Installing subfinder...${NC}"
GO111MODULE=on go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

echo -e "${YELLOW}  Installing httpx...${NC}"
GO111MODULE=on go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest

echo -e "${YELLOW}  Installing waybackurls...${NC}"
go install github.com/tomnomnom/waybackurls@latest

echo -e "${YELLOW}  Installing getJS...${NC}"
go install github.com/003random/getJS@latest

echo -e "${YELLOW}  Installing nuclei...${NC}"
GO111MODULE=on go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

echo -e "${YELLOW}  Installing gowitness...${NC}"
go install github.com/sensepost/gowitness@latest

# Update nuclei templates
echo -e "${YELLOW}  Updating nuclei templates...${NC}"
$GOPATH/bin/nuclei -update-templates || echo -e "${YELLOW}  Will update templates on first run${NC}"

# Create symlinks in /usr/local/bin for easy access
echo -e "${YELLOW}  Creating symlinks...${NC}"
ln -sf $GOPATH/bin/subfinder /usr/local/bin/subfinder 2>/dev/null
ln -sf $GOPATH/bin/httpx /usr/local/bin/httpx 2>/dev/null
ln -sf $GOPATH/bin/waybackurls /usr/local/bin/waybackurls 2>/dev/null
ln -sf $GOPATH/bin/getJS /usr/local/bin/getJS 2>/dev/null
ln -sf $GOPATH/bin/nuclei /usr/local/bin/nuclei 2>/dev/null
ln -sf $GOPATH/bin/gowitness /usr/local/bin/gowitness 2>/dev/null

# Step 4: Install R3CON script
echo -e "\n${CYAN}${BOLD}[4/5] Installing R3CON script...${NC}"
cat > /usr/local/bin/r3con << 'EOL'
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

${CYAN}  Respect is earned.  Access is taken. 
      Talk less.  Scan more
${NC}"

# Ensure domain argument is given
if [ -z "$1" ]; then
  echo -e "${RED}${BOLD}Usage: $0 <domain> [scan_params]${NC}"
  echo -e "${YELLOW}Optional:  Add 'params' as second argument to scan parameters (slow)${NC}"
  exit 1
fi

DOMAIN=$1
SCAN_PARAMS=${2:-"no"}
DATE=$(date +"%d-%m-%Y")
OUTDIR="Recon-$DOMAIN-$DATE"
mkdir -p "$OUTDIR"

echo -e "${CYAN}${BOLD}[1] Running subfinder... ${NC}"
subfinder -d "$DOMAIN" -silent > "$OUTDIR/subdomains.txt"
echo -e "${YELLOW}    Subdomains found: $(wc -l < "$OUTDIR/subdomains.txt")${NC}"
echo -e "${GREEN}    ✔ Subdomains stored at: $OUTDIR/subdomains.txt${NC}"

echo -e "${CYAN}${BOLD}[2] Probing live subdomains with httpx...${NC}"
httpx -l "$OUTDIR/subdomains.txt" -silent -mc 200,301,302 -threads 100 -timeout 5 > "$OUTDIR/live.txt"
echo -e "${YELLOW}    Live hosts found:  $(wc -l < "$OUTDIR/live.txt")${NC}"
echo -e "${GREEN}    ✔ Live hosts stored at: $OUTDIR/live.txt${NC}"

echo -e "${CYAN}${BOLD}[3] Fetching archive URLs with waybackurls...${NC}"
echo "$DOMAIN" | waybackurls > "$OUTDIR/wayback-main.txt"
echo -e "${YELLOW}    Wayback URLs found: $(wc -l < "$OUTDIR/wayback-main.txt")${NC}"
echo -e "${GREEN}    ✔ Wayback URLs stored at: $OUTDIR/wayback-main.txt${NC}"

echo -e "${CYAN}${BOLD}[4] Extracting URLs with parameters from wayback...${NC}"
grep '?' "$OUTDIR/wayback-main.txt" > "$OUTDIR/params. txt"
echo -e "${YELLOW}    Parameter URLs found: $(wc -l < "$OUTDIR/params. txt")${NC}"
echo -e "${GREEN}    ✔ Parameter URLs stored at: $OUTDIR/params.txt${NC}"

echo -e "${CYAN}${BOLD}[5] Extracting archived JS URLs from wayback...${NC}"
grep '\. js' "$OUTDIR/wayback-main.txt" > "$OUTDIR/js-files.txt"
echo -e "${YELLOW}    JS files found:  $(wc -l < "$OUTDIR/js-files.txt")${NC}"
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
echo -e "${YELLOW}    Scanning for vulnerabilities... ${NC}"
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
    echo -e "${YELLOW}    Taking a sample of 100 parameter URLs (out of $(wc -l < "$OUTDIR/params.txt"))... ${NC}"
    sort -R "$OUTDIR/params. txt" | head -n 100 > "$OUTDIR/params-sample.txt"

    echo -e "${YELLOW}    Scanning parameter sample with nuclei...${NC}"
    nuclei -l "$OUTDIR/params-sample.txt" -o "$OUTDIR/params-vulnerabilities.txt" -severity medium,high,critical -silent -timeout 5

    if [ -s "$OUTDIR/params-vulnerabilities.txt" ]; then
        echo -e "${RED}    PARAMETER VULNERABILITIES FOUND: $(wc -l < "$OUTDIR/params-vulnerabilities.txt")${NC}"
        echo -e "${RED}    Results preview:${NC}"
        cat "$OUTDIR/params-vulnerabilities.txt" | head -n 10
    else
        echo -e "${GREEN}    No vulnerabilities found in parameter sample${NC}"
    fi
    echo -e "${GREEN}    ✔ Parameter vulnerability results:  $OUTDIR/params-vulnerabilities.txt${NC}"
else
    echo -e "${YELLOW}    Skipping parameter scanning (URLs would take too long)${NC}"
    echo -e "${YELLOW}    To scan parameters, run: $0 $DOMAIN params${NC}"
fi

echo -e "${CYAN}${BOLD}[8] Taking screenshots of live hosts with GoWitness...${NC}"
mkdir -p "$OUTDIR/screenshots"
gowitness scan file -f "$OUTDIR/live.txt" -s "$OUTDIR/screenshots"
echo -e "${YELLOW}    Screenshots saved:  $(ls "$OUTDIR/screenshots" 2>/dev/null | wc -l)${NC}"
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
EOL

chmod +x /usr/local/bin/r3con

# Step 5: Verify installation
echo -e "\n${CYAN}${BOLD}[5/5] Verifying installation... ${NC}"

# Check each tool individually
MISSING_TOOLS=0

for tool in subfinder httpx waybackurls getJS nuclei gowitness; do
    if command -v $tool &> /dev/null; then
        echo -e "${GREEN}  ✓ $tool installed${NC}"
    else
        echo -e "${RED}  ✗ $tool not found${NC}"
        MISSING_TOOLS=$((MISSING_TOOLS + 1))
    fi
done

if [ $MISSING_TOOLS -eq 0 ]; then
  echo -e "\n${GREEN}${BOLD}✓ R3CON has been successfully installed!${NC}"
  echo -e "${YELLOW}Usage: r3con <domain> [params]${NC}"
  echo -e "${YELLOW}Example: r3con example.com${NC}"
  echo -e "${YELLOW}Example with parameter scanning: r3con example.com params${NC}"
  echo -e "\n${CYAN}Please run: source ~/. bashrc${NC}"
  echo -e "${CYAN}Or restart your terminal to use the tools. ${NC}"
else
  echo -e "\n${RED}${BOLD}✗ Installation incomplete. $MISSING_TOOLS tool(s) missing.${NC}"
  echo -e "${YELLOW}Please check the error messages above and try again. ${NC}"
  echo -e "${YELLOW}You may need to run: source ~/.bashrc and try again.${NC}"
fi

echo -e "\n${CYAN}${BOLD}Thank you for installing R3CON! ${NC}"
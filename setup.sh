#!/bin/bash
# AI Claw - Universal Automated Deployer (VPS & Local)

echo "======================================================"
echo "    AI Claw Alexa Skill - Automated Unified Setup"
echo "======================================================"

# 1. Ask for Telegram ID & Voice Options
echo "======================================================"
echo "Delivery Configuration"
echo "======================================================"
echo "OpenClaw will natively deliver your background LLM responses via Telegram."
read -p "Enter your numeric Telegram Chat ID: " TELEGRAM

echo ""
echo "Optional: Do you also want OpenClaw to asynchronously speak the final response out loud via your Echo speaker? (Requires the unofficial 'alexa' CLI terminal tool installed on your VPS)."
read -p "Enable dual voice delivery? (y/n): " VOICE_CHOICE

VOICE_DEVICE=""
if [ "$VOICE_CHOICE" == "y" ]; then
    read -p "Enter the exact name of your targeting Echo speaker (e.g. 'Living Room Echo'): " VOICE_DEVICE
fi
echo ""

echo "======================================================"
echo "Tunneling Configuration"
echo "======================================================"

URL=""
TUNNEL_CHOICE=""

if command -v tailscale &> /dev/null; then
    echo "[Found] Tailscale is installed on this system."
    TUNNEL_CHOICE="t"
fi
if command -v ngrok &> /dev/null; then
    echo "[Found] ngrok is installed on this system."
    if [ "$TUNNEL_CHOICE" == "t" ]; then
        read -p "Both are installed. Use ngrok (n) or tailscale (t)? (n/t): " TUNNEL_CHOICE
    else
        TUNNEL_CHOICE="n"
    fi
fi

if [ -z "$TUNNEL_CHOICE" ]; then
    echo "❌ Neither 'ngrok' nor 'tailscale' were found in your PATH."
    echo "Please install ngrok or tailscale before running this script."
    exit 1
fi

if [ "$TUNNEL_CHOICE" == "t" ]; then
    echo "Starting Tailscale Funnel in the background on port 18789..."
    tailscale funnel 18789 > /dev/null 2>&1 &
    sleep 2
    echo "✅ Tailscale Funnel is running!"
    read -p "Enter your Tailscale Funnel URL (e.g. https://machine.tailnet.ts.net): " URL
else
    echo "Starting ngrok tunnel in the background on port 18789..."
    pkill ngrok 2>/dev/null
    nohup ngrok http 18789 > /dev/null 2>&1 &
    
    echo "Waiting for ngrok to secure a public URL..."
    sleep 3
    
    URL=$(python3 -c "
import json, urllib.request
try:
    req = urllib.request.urlopen('http://127.0.0.1:4040/api/tunnels')
    data = json.loads(req.read())
    print(data['tunnels'][0]['public_url'])
except Exception:
    print('')
")
    
    if [ -z "$URL" ]; then
        echo "❌ Failed to automatically fetch ngrok URL."
        read -p "Please enter your ngrok URL manually: " URL
    else
        echo "✅ Automatically fetched ngrok URL: $URL"
    fi
fi

# Ensure URL has /hooks/agent correctly formatted
if [[ $URL != *"/hooks/agent"* ]]; then
    URL="${URL%/}/hooks/agent"
fi

# 2. OpenClaw Config Automation
TOKEN=$(openssl rand -hex 24)
OPENCLAW_CONFIG_PATH="$HOME/.openclaw/openclaw.json"

echo "======================================================"
echo "Configuring Gateway Security"
echo "======================================================"

if [ -f "$OPENCLAW_CONFIG_PATH" ]; then
    echo "Found openclaw.json on this machine! Automating Gateway security..."
    python3 -c "
import json
import sys

config_path = sys.argv[1]
token = sys.argv[2]

try:
    with open(config_path, 'r') as f:
        data = json.load(f)
    
    data['hooks'] = {
        'enabled': True,
        'path': '/hooks',
        'token': token,
        'allowedAgentIds': [],
        'defaultSessionKey': 'hook:ingress'
    }
    
    with open(config_path, 'w') as f:
        json.dump(data, f, indent=2)
    print('✅ Successfully injected secure webhooks block into openclaw.json.')
except Exception as e:
    print(f'⚠️ Failed to automatically edit openclaw.json (it might be JSON5 formatted): {e}')
" "$OPENCLAW_CONFIG_PATH" "$TOKEN"
    echo "⚠️ IMPORTANT: Please restart your OpenClaw service manually after this script finishes."
else
    echo "openclaw.json not found locally. Assuming you are deploying entirely from your laptop instead of the VPS."
    echo "Your newly generated secure webhook token is: $TOKEN"
fi

# 3. Inject Lambda variables into a GITIGNORED private copy (never overwrite the public template!)
echo "Injecting configured variables into a private lambda_generated.py (gitignored)..."
python3 -c "
import sys
content = open('lambda/lambda_function.py').read()
content = content.replace('YOUR_NEW_PRACTICALLY_UNGUESSABLE_TOKEN', sys.argv[1])
content = content.replace('YOUR_TELEGRAM_CHAT_ID_HERE', sys.argv[2])
content = content.replace('https://YOUR_FORWARDING_URL.ngrok-free.app/hooks/agent', sys.argv[3])
if sys.argv[4]:
    content = content.replace('VOICE_ECHO_DEVICE = \"\"', f'VOICE_ECHO_DEVICE = \"{sys.argv[4]}\"')
open('lambda_generated.py', 'w').write(content)
" "$TOKEN" "$TELEGRAM" "$URL" "$VOICE_DEVICE"
echo "✅ Private lambda_generated.py created. Copy this file into the Alexa Developer Console Code tab."

# 4. ASK CLI Deployment
echo "======================================================"
echo "Preparing for Amazon Alexa Web Deployment"
echo "======================================================"

if ! command -v ask &> /dev/null; then
    echo "❌ The Amazon 'ask-cli' is not installed."
    echo "Please install it with: npm install -g ask-cli"
    exit 1
fi

echo "Would you like to authenticate ASK CLI in headless mode (perfect for VPS)?"
echo "This will give you a URL to copy/paste into your laptop browser."
echo "⚠️ NOTE: If you link your AWS account in the next step, you MUST provide keys for an IAM User with 'AWSLambda_FullAccess' and 'IAMFullAccess' policies attached!"
read -p "Use --no-browser authentication? (y/n): " HEADLESS
if [ "$HEADLESS" == "y" ]; then
    ask configure --no-browser
else
    ask configure
fi

echo "Deploying skill and AWS Lambda to your Amazon account..."
ask deploy

echo "======================================================"
echo "✅ Success! AI Claw is deployed and your connection is primed!"
echo "Your tunnel is running in the background! You can speak to Alexa right now!"

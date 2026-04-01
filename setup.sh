#!/bin/bash
# AI Claw - Automated Configuration Script

echo "Welcome to the AI Claw Alexa Skill Configuration!"
echo "This script will inject your private credentials into the Lambda payload."
echo "--------------------------------------------------------"

read -p "Enter your OpenClaw Webhook Token: " TOKEN
read -p "Enter your numeric Telegram Chat ID: " TELEGRAM
read -p "Enter your tunneling Forwarding URL (e.g. https://abc.ngrok-free.app): " URL

# Ensure URL has /hooks/agent correctly formatted
if [[ $URL != *"/hooks/agent"* ]]; then
    URL="${URL%/}/hooks/agent"
fi

echo "Updating lambda/lambda_function.py..."

# Reliable Python string replacement
python3 -c "
import sys
content = open('lambda/lambda_function.py').read()
content = content.replace('YOUR_NEW_PRACTICALLY_UNGUESSABLE_TOKEN', sys.argv[1])
content = content.replace('YOUR_TELEGRAM_CHAT_ID_HERE', sys.argv[2])
content = content.replace('https://YOUR_FORWARDING_URL.ngrok-free.app/hooks/agent', sys.argv[3])
open('lambda/lambda_function.py', 'w').write(content)
" "$TOKEN" "$TELEGRAM" "$URL"

echo "--------------------------------------------------------"
echo "Success! Your backend is fully configured!"
echo ""
echo "If you have the ASK CLI installed and configured with AWS, you can now instantly deploy by running:"
echo "  $ ask deploy"
echo ""
echo "Otherwise, you can manually upload the 'lambda_function.py' file to the Alexa Developer Console!"

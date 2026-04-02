# AI Claw - OpenClaw Alexa Integration

This repository provides an open-source, serverless Python bridge between Amazon Alexa and your local [OpenClaw](https://openclaw.ai) gateway via Amazon's free **"Alexa-Hosted Skills"**.

Because OpenClaw executes deep, autonomous agentic workflows, it takes vastly longer than Amazon's strict 8-second AWS Lambda timeout limit. Therefore, this integration deliberately relies on a dual-delivery asynchronous architecture to bypass it:
* It pings your **Telegram** natively when finished.
* It can dynamically command your physical **Echo device** to speak the answer aloud natively via `alexa-cli`!

---

## 📥 Getting Started

Before choosing an installation path, you must download this repository to your computer or VPS:

```bash
git clone https://github.com/abhinav-TB/openclaw-alexa
cd openclaw-alexa
```

---

## 🌉 Setting up the Secure Tunnel

Because Amazon's Alexa Developer Cloud exists on the public internet, it cannot natively talk directly to your private local OpenClaw gateway. You **MUST** expose your OpenClaw webhook port securely over HTTPS using a reverse proxy tunnel.

You have two primary options for this:

### Option A: Tailscale Funnel (Recommended)
Tailscale is a zero-config mesh VPN. Its "Funnel" feature exposes local ports securely to the open internet via natively trusted Let's Encrypt certificates.
1. Install Tailscale on your OpenClaw VPS.
2. Run this command to expose the webhook port:
   ```bash
   tailscale funnel 18789
   ```
3. Copy the URL generated (e.g. `https://your-machine.tailnet.ts.net`).
4. **Why this is recommended:** Tailscale Funnel runs natively as a persistent background service daemon. You do not need to use terminal multiplexers to keep it alive when you log out of your VPS!

### Option B: Ngrok
Ngrok is the industry standard for fast reverse proxying.
1. Install ngrok and authenticate your account.
2. Because ngrok natively closes when you exit your SSH session, you **must** use a terminal multiplexer like `tmux` to keep it alive indefinitely in the background!
3. Start a new background session: 
   ```bash
   tmux new -s tunnel
   ```
4. Start ngrok targeting OpenClaw: 
   ```bash
   ngrok http 18789
   ```
5. Copy your Forwarding URL (e.g. `https://abc-123.ngrok-free.app`).
6. Detach from the session so it stays running in the background: press `Ctrl+B`, release, then press `D`.

---

## 🛠️ Path 1: The Manual Setup (Recommended / Stable)
You can manually build the integration using Amazon's free graphical web interface. This is the most stable method and ensures you completely understand how the architecture works.

### 1. Enable Secure Webhooks in OpenClaw
By default, the incoming webhook API in OpenClaw is disabled to protect your server. You must enable it securely to accept Alexa's connection.
* Generate a random 24-character security token (e.g. run `openssl rand -hex 24` in your terminal).
* Open your OpenClaw configuration file (`$HOME/.openclaw/openclaw.json`).
* Add a new `"hooks"` block next to your existing `"gateway"` block exactly like this:
   ```json
   "hooks": {
     "enabled": true,
     "path": "/hooks",
     "token": "YOUR_NEW_PRACTICALLY_UNGUESSABLE_TOKEN",
     "allowedAgentIds": [],
     "defaultSessionKey": "hook:ingress"
   }
   ```
* Restart your OpenClaw daemon for the security changes to take effect.

### 2. Create the Alexa Skill
* Go to the [Alexa Developer Console](https://developer.amazon.com/alexa/console/ask) and log in.
* Click **Create Skill**.
* **Skill Name:** `AI Claw` *(Note: Amazon's native policies reject the word "Open" in names).*
* **Primary Locale:** English (US).
* **Experience, Model, Hosting:** Choose **Other**, **Custom**, and **Alexa-Hosted (Python)**.
* Click **Create**.

### 3. Setup the Interaction Model
This tells Amazon's servers how to listen to your voice and map your sentences into code variables.
* On the left sidebar, click **Interaction Model** -> **Intents**.
* Click **Add Intent** and name it `PassThroughIntent`.
* Add a new slot named `Query`, and set its type to `AMAZON.SearchQuery`.
* Under **Sample Utterances**, add these wake-word carrier phrases **one by one**: 
   * `search for {Query}`
   * `i want to {Query}`
   * `can you {Query}`
   * `to {Query}`
   *(Example: "Alexa, ask AI Claw **to** turn on the lights").*
* **CRITICAL:** Click **Save Model**, and then click the blue **Build Skill** button at the top. Wait for it to finish.

### 4. Deploy the Python Code
* Click the **Code** tab at the top of the Developer Console.
* Replace the default `lambda_function.py` and `requirements.txt` files with the contents found inside the `lambda/` folder of this repository.
* Update the **Global Configuration Variables** (around line 17) inside the `lambda_function.py` editor to link your custom VPS:
   * **URL:** Your assigned Tailscale or Ngrok tunnel Forwarding URL *(you must append `/hooks/agent` to the end!)*.
   * **Token:** The exact secure token you generated in Step 1.
   * **Telegram ID:** `YOUR_TELEGRAM_CHAT_ID_HERE` *(Required to guarantee asynchronous delivery fallback).*
   * **Voice Device:** (Optional) Enter your exact specific speaker name (e.g. `"Living Room Echo"`) to enable autonomous AI voice playback. Leave empty to safely disable.
* Click **Deploy**.

### 5. Setup Voice Responses (Optional)
If you populated the `VOICE_ECHO_DEVICE` parameter in Step 4 to magically hear your physical speaker talk to you instead of just texting you via Telegram, you must configure your OpenClaw VPS to support it:
1. You must install the community [`alexa-cli`](https://github.com/openclaw/skills/blob/main/skills/buddyh/alexa-cli) tool natively on your OpenClaw VPS run environment (`npm install -g alexacli`).
2. Run `alexacli auth` in your VPS terminal to securely link your Amazon account to the local machine.
3. Use `alexacli devices` to verify that your target speaker name perfectly matches the hardcoded string you put in the Python code!
4. **CRITICAL - Prime your Agent:** Go right into your OpenClaw web interface and explicitly tell your agent to remember the tool! Send it a message like: *"Please remember that whenever a webhook request asks you to speak to an Alexa device, you must proactively execute the `alexacli` skill to natively deliver your response."*

---

## 🚀 Path 2: The Automated Setup Script (Experimental / Under Development)
If you are an advanced power user with the [Amazon ASK CLI](https://developer.amazon.com/en-US/docs/alexa/smapi/quick-start-alexa-skills-kit-command-line-interface.html) installed locally on your machine, you can run our initialization script to dynamically generate your Python code and cleanly deploy your skills natively!

**1. Run the Automated Setup Script:**
Run the configuration script from your terminal:
```bash
./setup.sh
# (If you get a permission error, run: chmod +x setup.sh)
```
* It will prompt you for your Telegram ID and target Voice Echo device.
* It will automatically detect if you have `ngrok` or `tailscale` installed, silently spin up a background terminal tunnel implicitly, and dynamically fetch the remote URL string natively using Python APIs!
* It intelligently evaluates and injects the secure Webhooks block into your OpenClaw JSON framework locally.
* It sets up your entire Amazon Developer deployment natively over headless terminal architecture!

---

## 🎙️ How to Test
You can test the deployment using the **Test** tab in the Developer Console Simulator or using a physical Echo device logged into the same Amazon account. 

For the most reliable testing results in the Simulator, **always use full sentences.** If you use fragmented sentences, Amazon's native Alexa AI might falsely hijack your conversation before it routes to OpenClaw.

* **Correct Test Input:**
  `ask ai claw to check the servers`
  -> *Alexa Response:* "I have sent your request to AI Claw!"

If your OpenClaw agent is configured correctly, your final LLM generated answer will cleanly be autonomously delivered roughly 15-30 seconds later:
* **Telegram Delivery:** Your Telegram app will instantly ping you with the answer!
* **Voice Delivery:** Your physical Echo device will autonomously speak the answer out loud completely bypassing Amazon's 8-second rule!

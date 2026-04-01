# AI Claw - OpenClaw Alexa Integration

This repository provides an open-source, serverless Python bridge between Amazon Alexa and your local [OpenClaw](https://openclaw.ai) gateway. By utilizing Amazon's free **"Alexa-Hosted Skills"** and a local tunnel, you can control your OpenClaw agent entirely hands-free from an Echo device, with zero cloud hosting costs. 

Crucially, this integration routes your Alexa commands to OpenClaw's background Webhook API, allowing it to process complex agentic workflows asynchronously and automatically deliver the final response to your paired **Telegram** account!

## Architecture

1. You say: *"Alexa, ask AI Claw to summarize my emails."*
2. Alexa hits the **AWS Lambda (Python)** hosted for free by Amazon.
3. The Lambda securely forwards the request to your local tunnel.
4. The tunnel routes it to the `/hooks/agent` webhook endpoint running on your OpenClaw gateway.
5. OpenClaw receives the request, spins up the LLM agent, and delivers the final answer directly to your Telegram app.

---

## 1. Prerequisites & Gateway Setup

### 1a. Clone the Repository
Start by cloning this repository to your local machine:
```bash
git clone https://github.com/YOUR_USERNAME/openclaw-alexa.git
cd openclaw-alexa
```

### 1b. Enable Secure Webhooks in OpenClaw
By default, the incoming webhook API in OpenClaw is disabled. You must enable it securely to prevent unauthorized access.
1. Generate a brand new, highly random token (e.g. run `openssl rand -hex 24` in your terminal). **Do not reuse your main gateway token!**
2. Open your `openclaw.json` configuration file on your VPS.
3. Add a new `"hooks"` block next to your `"gateway"` block exactly like this:
   ```json
   "hooks": {
     "enabled": true,
     "path": "/hooks",
     "token": "YOUR_NEW_PRACTICALLY_UNGUESSABLE_TOKEN",
     "allowedAgentIds": [],
     "defaultSessionKey": "hook:ingress"
   }
   ```
   *(Note: Keeping `allowedAgentIds` empty locks down the webhook so callers cannot maliciously route to internal private agents.)*
4. Restart your OpenClaw service.

### 1c. Start the Local Gateway Tunnel
Because Alexa resides in the cloud and OpenClaw lives on your local machine/VPS, you need to expose OpenClaw's webhook to the internet securely. Choose one of the following methods:

#### Option A: Using ngrok (Easiest)
1. Run ngrok targeting the exact port OpenClaw is listening on (found in your `openclaw.json`, usually `18789`).
   ```bash
   ngrok http 18789
   ```
   *(Note: Do not use `https://localhost` here. OpenClaw expects standard HTTP locally, even though ngrok gives you a secure HTTPS URL for the web.)*
2. **Keep it running in the background:** If you run this on a VPS, use a terminal multiplexer like `tmux` or `screen`:
   * Start a session: `tmux new -s ngrok_tunnel`
   * Run your command: `ngrok http 18789`
   * Detach from the session (leave it running safely): Press **Ctrl + B**, let go, then press **D**.
   * **To stop it later:** Reattach to the session by typing `tmux attach -t ngrok_tunnel`, press **Ctrl + C** to kill ngrok, and type `exit` to close the tmux session.
3. Copy the `Forwarding` URL (e.g., `https://abc-123.ngrok-free.app`). Leave this terminal running!

#### Option B: Using Tailscale Funnel (Advanced)
If you already use Tailscale, you can securely expose your OpenClaw port to the public internet using Tailscale Funnel.
1. Run this command on your VPS to automatically expose the `18789` port:
   ```bash
   tailscale funnel 18789
   ```
2. Copy the generated Funnel URL (e.g., `https://your-machine.tailnet.ts.net`).
3. *(Unlike ngrok, Tailscale Funnel seamlessly persists as a background service, so you do not need to use `tmux`!)*

---

## 2. Deployment

You can deploy the Alexa skill logic using either the **Automated Path** (via terminal) or the **Manual Path** (via the web browser).

### Path A: Automated CLI Deployment (Fastest)
If you have the [Amazon ASK CLI](https://developer.amazon.com/en-US/docs/alexa/smapi/quick-start-alexa-skills-kit-command-line-interface.html) installed and linked to an AWS account, you can deploy the entire skill and interaction model instantly bypassing the Web Console.

1. Inside the cloned repository folder, run the configuration script: 
   ```bash
   ./setup.sh
   # (If you get a permission error, run: chmod +x setup.sh)
   ```
2. Enter your **Forwarding URL**, your **Secure Token**, and your **Telegram Chat ID** when prompted. The script will automatically inject these into the Python code array.
3. Run the Alexa deployment command to push the skill and Lambda directly to your AWS account:
   ```bash
   ask deploy
   ```
4. You are done! Skip to the "How to Test" section.

---

### Path B: Manual Deployment (Easiest for Beginners)
If you do not have the ASK CLI installed, you can easily build this using Amazon's free graphical interface.

**Step 1. Create the Alexa Skill**
1. Go to the [Alexa Developer Console](https://developer.amazon.com/alexa/console/ask).
2. Click **Create Skill**.
3. **Skill Name:** `AI Claw` *(Note: Amazon rejects the word "Open" natively, so you cannot name it Open Claw).*
4. **Primary Locale:** Choose your language.
5. **Experience, Model, Hosting:** Choose **Other**, **Custom**, and **Alexa-Hosted (Python)**.
6. Click **Next** -> **Create Skill**. It takes about a minute to spin up the free server.

**Step 2. Setup the Interaction Model**
We need to tell Alexa to pass exactly what you say to Python, instead of trying to map specific commands.
1. On the left sidebar, click **Interaction Model** -> **Intents**.
2. Click **Add Intent**. Give it the custom name `PassThroughIntent`.
3. Scroll down to **Intent Slots**, add a new slot named `Query`.
4. Set the Slot Type to `AMAZON.SearchQuery` (this tells Alexa to accept raw text).
5. Scroll up to **Sample Utterances**. You MUST add these **one by one** (type the line, hit **Enter** so it moves down into the list, then type the next line):
   - `search for {Query}`
   - `i want to {Query}`
   - `can you {Query}`
   - `to {Query}`
   *(Note: Amazon's compiler requires these "carrier words" for SearchQuery slots. It will crash your build if you try to add `{Query}` by itself!)*
6. **CRITICAL:** Click **Save Model**, and then you MUST click the blue **Build Skill / Build Model** button at the top right.

**Step 3. Deploy the Python Code**
1. Click the **Code** tab at the top of the Developer Console.
2. Open `lambda_function.py` and replace everything inside with the contents of the `lambda/lambda_function.py` file from this repository.
3. Open `requirements.txt` and replace its contents with the `lambda/requirements.txt` from this repository.
4. Update the **Global Configuration Variables** (around line 17) inside `lambda/lambda_function.py`. You must add your specific URL, Token, and Telegram Chat ID.
   * **URL:** Ensure you append `/hooks/agent` to the end.
   * **Token:** Your newly generated secure token.
   * **Telegram ID:** Your numeric Telegram Chat ID (e.g. `123456789`) so OpenClaw knows who to deliver the payload to.
5. Click **Deploy**.

---

## 3. How to Test Successfully
You can test using the **Test** tab in the Developer Console Simulator or a real physical Echo device. 

For the most reliable testing results in the Simulator, **always use full sentences.** If you use fragmented sentences, Amazon's native Alexa AI might hijack your conversation.

* **Correct Test Input:**
  `ask ai claw to check the servers`
  -> *Alexa Response:* "I have sent your request to AI Claw! It will message you when finished."

If your OpenClaw agent is configured correctly, your Telegram app will instantly ping you with the answer!

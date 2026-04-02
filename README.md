# AI Claw - OpenClaw Alexa Integration

This repository provides an open-source, serverless Python bridge between Amazon Alexa and your local [OpenClaw](https://openclaw.ai) gateway via Amazon's free **"Alexa-Hosted Skills"**.

Crucially, this integration routes your Alexa commands to OpenClaw's background Webhook API, allowing it to process complex agentic workflows asynchronously and automatically deliver the final response to your paired **Telegram** account, or directly out loud via your **Alexa Echo Speaker**!

---

## 📥 Getting Started

Before choosing an installation path, you must download this repository to your computer or VPS:

```bash
git clone https://github.com/YOUR_USERNAME/openclaw-alexa.git
cd openclaw-alexa
```

---

## 🛠️ Path 1: The Manual Setup (Recommended / Stable)
You can manually build the integration using Amazon's free graphical web interface. This is the most stable method.

**1. Start your local tunnel**
On your OpenClaw machine, start your `ngrok` or `tailscale` tunnel targeting port 18789. Keep the Forwarding URL handy!

**2. Enable Secure Webhooks in OpenClaw**
By default, the incoming webhook API in OpenClaw is disabled. You must enable it securely.
* Generate a random token (e.g. `openssl rand -hex 24`), log into your VPS, and add a new `"hooks"` block next to your `"gateway"` block exactly like this:
   ```json
   "hooks": {
     "enabled": true,
     "path": "/hooks",
     "token": "YOUR_NEW_PRACTICALLY_UNGUESSABLE_TOKEN",
     "allowedAgentIds": [],
     "defaultSessionKey": "hook:ingress"
   }
   ```
* Restart your OpenClaw service.

**3. Create the Alexa Skill**
* Go to the [Alexa Developer Console](https://developer.amazon.com/alexa/console/ask) and click **Create Skill**.
* **Skill Name:** `AI Claw` *(Amazon rejects the word "Open" natively).*
* **Options:** Choose **Other**, **Custom**, and **Alexa-Hosted (Python)**. Click Create.

**4. Setup the Interaction Model**
* On the left sidebar, click **Interaction Model** -> **Intents**.
* Click **Add Intent** and name it `PassThroughIntent`.
* Add a new slot named `Query`, and set its type to `AMAZON.SearchQuery`.
* Under **Sample Utterances**, add these **one by one**: `search for {Query}`, `i want to {Query}`, `can you {Query}`, `to {Query}`.
* **CRITICAL:** Click **Save Model**, and then click the blue **Build Skill** button.

**5. Deploy the Python Code**
* Click the **Code** tab at the top of the Developer Console.
* Replace the `lambda_function.py` and `requirements.txt` files with the contents found inside the `lambda/` folder of this repository.
* Update the **Global Configuration Variables** (around line 17) inside the `lambda_function.py` editor:
   * **URL:** Your Forwarding URL (ensure you append `/hooks/agent` to the end).
   * **Token:** Your newly generated secure token.
   * **Telegram ID:** Your numeric Telegram Chat ID (`123456789`).
   * **Voice Device:** (Optional) Enter your exact speaker name (e.g. `"Living Room Echo"`) to enable asynchronous voice playbacks.
* Click **Deploy**.

**6. Setup Voice Responses (Optional)**
If you set a *Voice Device* in Step 5 to receive spoken voice playbacks instead of just Telegram messages:
* You must install the community [`alexa-cli`](https://github.com/openclaw/skills/blob/main/skills/buddyh/alexa-cli) on your OpenClaw VPS (`npm install -g alexacli`).
* Run `alexacli auth` in your VPS terminal to securely link your Amazon account.
* Use `alexacli devices` to verify your target speaker name perfectly matches the name you put in the Python code!
* **CRITICAL - Prime your Agent:** Go right into your OpenClaw web interface and explicitly tell your agent to remember the tool! Send it a message like: *"Please remember that whenever a webhook request asks you to speak to an Alexa device, you must proactively load and use your `alexacli` skill to deliver it."*

---

## 🚀 Path 2: The Automated Setup Script (Experimental / Under Development)
If you have the [Amazon ASK CLI](https://developer.amazon.com/en-US/docs/alexa/smapi/quick-start-alexa-skills-kit-command-line-interface.html) installed on your machine, you can run our initialization script to dynamically generate your Python code and deploy it headless.

**1. Run the Automated Setup Script:**
Run the configuration script from your terminal:
```bash
./setup.sh
# (If you get a permission error, run: chmod +x setup.sh)
```
* It will prompt you for your Telegram ID and target Voice Echo device.
* It will automatically detect if you have `ngrok` or `tailscale` and silently spin up a background tunnel and fetch the URL.
* It intelligently injects the secure Webhooks block into your OpenClaw JSON framework locally.
* It sets up your Amazon Developer deployment natively over headless authentication!

---

## 🎙️ How to Test
You can test using the **Test** tab in the Developer Console Simulator or a physical Echo device logged into the same Amazon account. 

For the most reliable testing results in the Simulator, **always use full sentences.** If you use fragmented sentences, Amazon's native Alexa AI might hijack your conversation.

* **Correct Test Input:**
  `ask ai claw to check the servers`
  -> *Alexa Response:* "I have sent your request to AI Claw!"

If your OpenClaw agent is configured correctly, your answer will be delivered asynchronously:
* **Telegram Delivery:** Your Telegram app will instantly ping you with the answer!
* **Voice Delivery:** Your physical Echo device will autonomously speak the answer out loud using the `alexa-cli` integration!

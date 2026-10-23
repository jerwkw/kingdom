# Archived Raspberry Pi Setup & Deployment Guide

> This deployment path is no longer supported. Kingdom now uses Firebase Cloud
> Functions. This document is historical reference only; follow the root
> `FIREBASE_DEPLOYMENT_GUIDE.md` (on the `documentation` branch) for development and production.

This guide walks through setting up your Node.js backend server on a Raspberry Pi to handle privileged game logic (reward transactions, building stats aggregation, and daily challenge generation) without needing a paid Cloud Functions setup or credit card.

---

## 📋 Prerequisites

1. **Raspberry Pi** (Model 3B, 4, 5, or Zero 2 W) running Raspberry Pi OS (32-bit or 64-bit Lite).
2. **Local Network Access** to the Pi via SSH (`ssh pi@<pi-ip-address>`).
3. **Firebase Service Account Key** from your Firebase Project Console.

---

## 🛠️ Step 1: Firebase Service Account Key Setup

1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Select your project -> **Project Settings (⚙️ icon)** -> **Service Accounts**.
3. Click **Generate new private key** and download the JSON file.
4. Rename this file to `service-account.json`.

> [!CAUTION]
> **Security Rule:** Never commit `service-account.json` to Git or send it to client devices. It has full admin rights to your Firebase project.

---

## 💻 Step 2: Install Node.js & Git on the Pi

SSH into your Raspberry Pi and install Node.js (LTS version):

```bash
# Update package indices
sudo apt update && sudo apt upgrade -y

# Install Node.js 20.x LTS via NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs git build-essential

# Verify installation
node -v   # Should output v20.x.x
npm -v    # Should output v10.x.x
```

---

## 📁 Step 3: Copy Code & Dependencies to the Pi

Transfer the `server/` directory to the Raspberry Pi (or clone your repository):

```bash
# Example: Create directory on Pi
mkdir -p ~/kingdom-server
cd ~/kingdom-server

# Copy service-account.json into ~/kingdom-server/
# Set environment variables
cp .env.example .env

# Install Node dependencies
npm install --production
```

---

## 🌐 Step 4: Expose Server with Cloudflare Tunnel (Free & Secure)

Cloudflare Tunnel exposes your local Node port (3000) over a secure public HTTPS URL without needing a static public IP or port forwarding on your router.

```bash
# 1. Download and install cloudflared
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
sudo dpkg -i cloudflared.deb

# 2. Authenticate cloudflared with your free Cloudflare account
cloudflared tunnel login

# 3. Create a named tunnel
cloudflared tunnel create kingdom-pi-tunnel

# 4. Route traffic to your server (e.g. quick tunnel or custom domain)
cloudflared tunnel run --url http://localhost:3000 kingdom-pi-tunnel
```

Copy the generated HTTPS URL (e.g. `https://kingdom-pi-tunnel.trycloudflare.com` or your custom domain). This is the **Pi Server Base URL** used by the Flutter client.

---

## 🔄 Step 5: Process Management with PM2 (Auto-Restart)

Use `pm2` so the server automatically starts when the Raspberry Pi boots or reboots.

```bash
# Install PM2 globally
sudo npm install -g pm2

# Start the server using PM2
cd ~/kingdom-server
pm2 start index.js --name "kingdom-pi-server"

# Configure PM2 to auto-start on system boot
pm2 startup
# (Run the command generated in terminal output, e.g. sudo env PATH=... pm2 startup systemd -u pi ...)

# Save the current process list
pm2 save
```

---

## ✅ Step 6: Verify Deployment

Run a quick curl test to confirm authentication and token verification:

```bash
# Test health check from your dev machine or browser
curl -X GET https://your-cloudflare-tunnel-url/health
```

Expected output:
```json
{ "error": "Unauthorized: Missing or malformed token" }
```
*(This confirms the auth middleware is active and protecting your server endpoints).*

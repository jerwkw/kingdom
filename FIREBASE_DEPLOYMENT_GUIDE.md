# Pure Firebase Deployment Guide (Cloud Functions + Hosting + Firestore)

This guide walks you through deploying the entire **Kingdom** application purely on Google Cloud Infrastructure using Firebase — **no Raspberry Pi or separate server setup required**.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   Firebase Hosting                          │
│          Serves Flutter Web App (CDN global)                │
└──────────────────────────────┬──────────────────────────────┘
                               │ /api/** rewrites
                               ▼
┌─────────────────────────────────────────────────────────────┐
│               Firebase Cloud Functions                      │
│   • Node.js 18 API (completeGoal, purchaseItem, etc.)      │
│   • Daily Challenge Scheduled Cron (1 0 * * * UTC)          │
└──────────────────────────────┬──────────────────────────────┘
                               │ Admin SDK
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 Cloud Firestore Database                    │
│   • Enforces firestore.rules for direct client reads        │
│   • Atomic transactions for fish balances & group funds     │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Prerequisites

1. **Node.js** (v18 or higher installed on your dev laptop)
2. **Flutter SDK**
3. **Firebase Account & Project** (created at [console.firebase.google.com](https://console.firebase.google.com))

---

## 🚀 Step-by-Step Deployment Instructions

### Step 1: Install Functions Dependencies

Navigate to the `functions/` directory and install dependencies:

```bash
cd functions
npm install
cd ..
```

### Step 2: Authenticate Firebase CLI

Log into your Firebase account from your laptop terminal:

```bash
npx -y firebase-tools@latest login
```

Select your active Firebase Project ID:

```bash
npx -y firebase-tools@latest use <YOUR_FIREBASE_PROJECT_ID>
```

*(If you don't have a project created yet, run `npx -y firebase-tools@latest projects:create kingdom-app`)*

---

### Step 3: Build the Flutter Web Application

Build the static production web assets:

```bash
export PATH="/Users/jeremywong/flutter/bin:$PATH"  # or your flutter path
flutter build web
```

This generates the web build inside `build/web/`.

---

### Step 4: Deploy Everything to Firebase in One Command

Deploy Firestore Security Rules, Cloud Functions, and Firebase Hosting together:

```bash
npx -y firebase-tools@latest deploy
```

*(Or deploy specific components individually if needed:)*
- **Cloud Functions only**: `npx -y firebase-tools@latest deploy --only functions`
- **Hosting only**: `npx -y firebase-tools@latest deploy --only hosting`
- **Firestore rules only**: `npx -y firebase-tools@latest deploy --only firestore:rules`

---

## 🛠️ Local Testing / Emulator (Optional)

You can run the entire stack locally using the official Firebase Emulators before deploying:

```bash
npx -y firebase-tools@latest emulators:start
```

This starts:
- Local Firestore Emulator on port `8080`
- Local Cloud Functions Emulator on port `5001`
- Local Hosting Emulator on port `5000`

---

## 🔒 Security Summary

- **Client Reads**: Secured by `firestore.rules` (only user's own goals & completed records can be read/modified directly).
- **Client Writes**: Restricted — clients cannot modify their fish balances or group fund directly.
- **Privileged Operations**: Handled strictly via authenticated Firebase Cloud Functions (`api` endpoint) using Firebase ID Tokens.

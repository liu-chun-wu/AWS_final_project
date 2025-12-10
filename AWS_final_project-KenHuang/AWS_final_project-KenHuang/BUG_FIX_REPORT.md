# Bug Fix & Testing Report

This document outlines the specific fix applied to resolve the "500 Error / Image Download Failure" reported in the bug log, and instructions on how to verify it.

## 1. The Issue
**Symptom:** When using the `/create_photo` command, the Discord bot would return a 500 error or a message stating it could not download the image.
**Root Cause:**
1.  The Flask backend generates an image and returns a `local_url` (e.g., `http://localhost:5000/...`).
2.  The Discord bot attempted to use `aiohttp` or `requests` to download this image from `localhost`.
3.  This network request often fails in local environments (connection refused, DNS issues with localhost) or simply because the bot cannot reach the server via that specific URL structure internally.

## 2. The Solution
**File Modified:** `backend/src/bot.py`

We modified the `create_photo` command logic to prioritize **direct file access** over HTTP requests.

*   **Old Logic:** Always try to download the image from `http://localhost:5000/...`.
*   **New Logic:**
    1.  Check if `local_path` (the physical file path on disk) exists.
    2.  If it exists, open the file directly using Python's `open()` function.
    3.  Send this file object directly to Discord.
    4.  *Fallback:* If the file can't be read locally, only then try to download via the URL.

This eliminates the network hop for local files, making the bot significantly more robust when running on the same machine as the backend.

## 3. How to Test

### Prerequisites
1.  Ensure you have the necessary tokens (`DISCORD_TOKEN`, `HUGGINGFACE_TOKEN`) in your `.env` file.
2.  Ensure "Message Content Intent" is enabled for your bot in the Discord Developer Portal.

### Step-by-Step Testing
1.  **Stop** any other running instances of the bot or backend.
2.  **Terminal 1 (Backend):**
    ```bash
    cd "D:\ncu\雲端\AWS_final_project\AWS_final_project-KenHuang\AWS_final_project-KenHuang"
    python backend/src/app.py
    ```
3.  **Terminal 2 (Bot):**
    ```bash
    cd "D:\ncu\雲端\AWS_final_project\AWS_final_project-KenHuang\AWS_final_project-KenHuang"
    python backend/src/bot.py
    ```
4.  **Discord:**
    Type the following command:
    ```
    /create_photo A futuristic city skyline
    ```
5.  **Verification:**
    *   The bot should respond with "Typing...".
    *   The bot should successfully upload the generated image.
    *   You should **not** see a 500 error or "Unable to download image" message.

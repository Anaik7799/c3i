# Guide: Google Cloud Pub/Sub Setup for GChat Ingress

**Version**: 1.0.0
**Date**: 2026-04-08
**Classification**: USER GUIDE / SIL-6 CONFIGURATION

## 1. Overview
To maintain the "Dark Cockpit" architecture (zero open inbound ports), Google Chat messages must be routed through a Google Cloud Pub/Sub topic instead of a direct HTTP Webhook. The Indrajaal `sa-plan-daemon` securely long-polls this queue via egress-only connections.

## 2. GCP Project Setup

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Select your `Indrajaal-Personal-OS` project.
3. Enable the **Cloud Pub/Sub API**.

## 3. Create the Pub/Sub Topic and Subscription

1. Navigate to **Pub/Sub** -> **Topics**.
2. Click **Create Topic**.
3. Name it `indrajaal-gchat-ingress`. Uncheck "Add a default subscription" (we will create one manually).
4. Navigate to **Subscriptions** -> **Create Subscription**.
5. Name it `indrajaal-gchat-pull`.
6. Select the `indrajaal-gchat-ingress` topic you just created.
7. Set Delivery Type to **Pull**.
8. Set Message Retention Duration to 1 Day.
9. Click **Create**.

## 4. Grant Google Chat Access to the Topic

To allow Google Chat to publish messages to your new topic, you must grant its service account access.

1. Go back to your `indrajaal-gchat-ingress` **Topic** details page.
2. In the Info Panel on the right, click **Add Principal**.
3. In "New Principals", enter exactly: `chat-api-push@system.gserviceaccount.com`
4. Select the Role: **Pub/Sub Publisher**.
5. Click **Save**.

## 5. Configure the Google Chat API

1. In the GCP Console, search for **Google Chat API** and click Manage.
2. Go to the **Configuration** tab.
3. Under "Connection settings", select **Cloud Pub/Sub**.
4. Enter the full Topic name (e.g., `projects/your-project-id/topics/indrajaal-gchat-ingress`).
5. Save the configuration.

## 6. Authorize the C3I Daemon

The Rust daemon uses the `gcloud` CLI tool (installed in `devenv.nix`) to automatically fetch OAuth tokens for the Pub/Sub API. 

1. On your host machine, run:
   ```bash
   gcloud auth application-default login
   ```
2. Authenticate with your `abhijit.naik@boutytek.com` account.
3. Tell the C3I system which project and subscription to pull from:
   ```bash
   ./sa-plan mcp --method set_preference --params '{"key": "gcp_project_id", "value": "your-gcp-project-id", "category": "config"}'
   ./sa-plan mcp --method set_preference --params '{"key": "gcp_pubsub_subscription", "value": "indrajaal-gchat-pull", "category": "config"}'
   ```

The daemon will now seamlessly pull Google Chat commands without exposing your machine to the internet.

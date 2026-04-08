# Diagnostic Report: Google Chat Ingress Failure (404 Not Found)

**Date**: 2026-04-09 00:30 CEST
**Classification**: SYSTEM DIAGNOSTIC / IAM PERMISSION FAILURE
**Subject**: Inability to ingest Google Chat commands via GCP Pub/Sub Polling.

## 1. Executive Summary
The human operator reported sending commands via Google Chat and receiving no response or Agentic UX updates ("Thinking...", "ETA: X").

A deep trace of the Rust `sa-plan-daemon`'s `ingress_polling.rs` module revealed that the system is successfully authenticating with Google Cloud using the provided ADC credentials, but is encountering a continuous `404 Not Found` HTTP error when attempting to pull messages.

## 2. Root Cause Analysis
The polling URL is:
`https://pubsub.googleapis.com/v1/projects/bountytek-db/subscriptions/indrajaal-gchat-pull:pull`

The `404 Not Found` indicates that the **Cloud Pub/Sub Topic and Subscription do not exist** on the `bountytek-db` project. 

The system attempted to autonomously provision these resources via the GCP REST API, but the ADC token returned a `403 PERMISSION_DENIED` error due to lacking the `pubsub.topics.create` IAM permission.

## 3. Architectural Reality (The Dark Cockpit)
Because we migrated to the **"Dark Cockpit" Egress-Only Polling Architecture**, the Indrajaal system can no longer receive messages "pushed" directly to it via webhooks. It relies entirely on an external buffer (the GCP Pub/Sub queue). 

If that queue is not manually created by an administrator in the Google Cloud Console, the system is permanently deaf to Google Chat.

## 4. Remediation Plan (Operator Action Required)
The operator must manually complete the physical infrastructure setup in Google Cloud:

1.  Log into `console.cloud.google.com` and select the `bountytek-db` project.
2.  Navigate to **Cloud Pub/Sub** -> **Topics**.
3.  Click **Create Topic** and name it `indrajaal-gchat-ingress`.
4.  Navigate to **Subscriptions** -> **Create Subscription**.
5.  Name it `indrajaal-gchat-pull` and link it to the topic above (Delivery Type: Pull).
6.  **Crucial Step**: In the Google Chat API settings, configure the bot to route messages to this specific Pub/Sub topic instead of an HTTP endpoint.

Until these steps are completed in the Google Console, the Personal OS will continue receiving 404 errors and cannot "hear" any Google Chat commands.

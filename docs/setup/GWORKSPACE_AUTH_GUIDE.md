# Guide: Google Workspace Production Access for Indrajaal C3I

To give your Personal OS access to your Google Workspace, follow these steps in the **[Google Cloud Console](https://console.cloud.google.com/)**:

## 1. Create a Project
1. Create a new project named `Indrajaal-Personal-OS`.
2. **Enable APIs**: Enable the following:
   - Gmail API
   - Google Calendar API
   - Google Drive API
   - Google Chat API

## 2. Configure OAuth Consent Screen
1. Set User Type to **Internal** (if using a business Workspace) or **External** (for personal Gmail).
2. **Add Scopes**:
   - `https://www.googleapis.com/auth/gmail.modify`
   - `https://www.googleapis.com/auth/calendar`
   - `https://www.googleapis.com/auth/drive.file`
   - `https://www.googleapis.com/auth/chat.messages`

## 3. Create Credentials
1. Go to **Credentials** -> **Create Credentials** -> **OAuth client ID**.
2. Select **Desktop App** as the Application Type.
3. Name it `C3I-Daemon`.
4. **Download the JSON**: This contains your `client_id` and `client_secret`.

## 4. Provide Credentials to C3I
Once you have the Client ID and Client Secret, provide them to me, and I will initiate the **Handshake Intent**.

# Fix: "Developer console is not set up correctly" (Google Sign-In on Android)

Error **28444** means the **Android** OAuth client in Google Cloud is missing or has the wrong package name / SHA-1.

## 1. Open Google Cloud Console

- Go to [Google Cloud Console](https://console.cloud.google.com/)
- Select the **same project** that has your Web client ID (`818773745181-1eq90ikmhev8vqf4ltof1a39m16oqgi4`).

## 2. Create or edit the Android OAuth client

1. Go to **APIs & Services** → **Credentials**.
2. Under **OAuth 2.0 Client IDs**:
   - If you **don’t** have an **Android** client: click **+ CREATE CREDENTIALS** → **OAuth client ID**.
   - If you **do** have an Android client for this app: click it to edit.
3. For **Application type** choose **Android**.
4. Use these values exactly:

   | Field           | Value |
   |----------------|--------|
   | **Package name** | `com.carauction.androidios` |
   | **SHA-1**        | `12:95:7C:5A:67:4C:B8:34:1D:AD:00:AB:39:B7:7D:A9:DA:63:5D:6C` |

   **Alternative SHA-1** (other dev machine / debug keystore):  
   `3D:96:B4:DA:F6:81:ED:34:66:79:DA:56:4F:8A:8B:06:AA:9F:25:BA`

5. (Optional) Add **SHA-256** for the same keystore (get via `keytool -list -v -keystore ...`):
   - Example: `75:28:02:89:79:08:84:51:A9:9C:B1:2F:6E:F6:E1:C0:BC:07:4C:D9:3A:73:22:13:1B:C0:18:A2:2C:9B:C9:A5`

6. Save (Create / Update).

## 3. Release builds (Play Store / signed APK)

If you later sign the app with a **release** keystore, add that keystore’s SHA-1 (and SHA-256) to the **same** Android OAuth client, or create a second Android client with the release package name + release SHA-1.  
Get fingerprints with:

```bash
keytool -list -v -keystore YOUR_RELEASE_KEYSTORE.jks -alias YOUR_ALIAS
```

## 4. Retest

- Uninstall the app from the device/emulator (to clear any cached auth).
- Run the app again and try **Sign in with Google**.

---

**Summary:** The Web client ID is already set in the app for the backend. The **Android** OAuth client in the same Google project must have package name `com.carauction.androidios` and the **debug** SHA-1 above. After adding them, error 28444 should go away.

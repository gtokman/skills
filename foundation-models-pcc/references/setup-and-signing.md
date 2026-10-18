# PCC setup and signing

Steps that took a test app from "entitlement approved" to working calls, including the
signing trap that blocks most people.

## 1. Get the entitlement

1. Join the App Store Small Business Program, if you aren't in it.
2. Request access at developer.apple.com/private-cloud-compute. If that page errors, the
   bottom of the *Adding server-side intelligence with Private Cloud Compute*
   documentation page has a request link too.
3. Wait for the email "The entitlement for Access to models on Private Cloud Compute has
   been assigned to your account". If you're enrolled as an organization, Admins can also
   use it.

## 2. Configure the App ID

Developer portal → Certificates, Identifiers & Profiles → Identifiers:

1. Register an **explicit** App ID, such as `com.example.MyApp`. Wildcard App IDs can't
   carry managed capabilities.
2. On the **Capabilities** tab, search "compute" and enable **Access to models on Private
   Cloud Compute**. Save.

## 3. Entitlements file

```xml
<key>com.apple.developer.private-cloud-compute</key>
<true/>
```

This is the key and value that Xcode-generated provisioning profiles grant, which we
verified by decoding the profile.

## 4. The signing trap: wildcard profile silently drops the entitlement

Even with the App ID configured, automatic signing (Xcode or
`xcodebuild -allowProvisioningUpdates`) can keep using **"iOS Team Provisioning Profile: \*"**.
That profile doesn't include the PCC entitlement, so the build **succeeds** but the
entitlement is stripped from the signed app and PCC calls fail at runtime.

**Fix:** in Xcode, target → Signing & Capabilities → **+ Capability** → add "Private Cloud
Compute". Xcode then generates an explicit profile named
"iOS Team Provisioning Profile: com.example.MyApp" that grants the entitlement. Doing this
doesn't change the entitlements file or add anything that xcodegen would overwrite, so
regenerating the project afterwards is safe.

Fallback: create an iOS App Development profile for the App ID by hand in the portal and
use manual signing with it.

### Verify

```sh
APP=path/to/Build/Products/Debug-iphoneos/MyApp.app
# Which profile was embedded, and does it grant PCC?
security cms -D -i "$APP/embedded.mobileprovision" \
  | plutil -extract Entitlements xml1 -o - - \
  | grep -A1 -E "application-identifier|private-cloud"
# Did the entitlement survive into the signature?
codesign -d --entitlements :- "$APP" | grep -A1 private-cloud
```

`application-identifier` must be `TEAMID.com.example.MyApp`, not `TEAMID.*`, and both
commands must show `com.apple.developer.private-cloud-compute`.

## 5. Run on a device

- **Physical device only.** Real PCC calls don't run in the Simulator. Use the scheme's
  *Simulate Apple Foundation Models Availability* option to test availability and quota UI.
- Needs an Apple Intelligence-capable device on OS 27 with Apple Intelligence turned on and
  a network connection.
- Testers: TestFlight or ad hoc. Those installs don't count toward the 2M-download limit.

## Not usable for shipping

- The macOS `fm` CLI and Python SDK (WWDC26 session 334) are handy for trying prompts, but
  a SwiftPM executable or `swift run` doesn't inherit an app's managed entitlement, and
  wrapping `fm` from a distributed app is a policy question Apple hasn't clearly answered.

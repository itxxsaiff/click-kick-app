# Android Release Signing

This project is now configured to use a real release keystore when
`android/key.properties` exists.

If `android/key.properties` is missing, the app still falls back to debug
signing so local release builds do not break.

## 1. Generate a real release keystore

Run this on your Mac:

```bash
keytool -genkeypair \
  -v \
  -keystore ~/clickkick-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias clickkick
```

Choose and save:
- keystore password
- key password
- alias

Do not commit this file to git.

## 2. Create `android/key.properties`

Copy the example file:

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties`:

```properties
storeFile=/Users/your-name/clickkick-release.jks
storePassword=your_store_password
keyAlias=clickkick
keyPassword=your_key_password
```

## 3. Build a real release APK

```bash
flutter build apk --release
```

Or AAB for Play Store:

```bash
flutter build appbundle --release
```

## 4. Update Android App Links fingerprint

This project uses Android App Links with:

- `web/.well-known/assetlinks.json`

Right now that file may still contain the old debug certificate fingerprint.
After moving to the real release keystore, generate the new SHA-256:

```bash
keytool -list -v -keystore ~/clickkick-release.jks -alias clickkick
```

Copy the `SHA256` fingerprint and replace the value in:

- `web/.well-known/assetlinks.json`

Then deploy hosting again:

```bash
flutter build web
firebase deploy --only hosting
```

## 5. Important notes

- `android/key.properties` is already ignored by git.
- `*.jks` and `*.keystore` are already ignored by git in `android/.gitignore`.
- Never share keystore files or passwords in chat, git, or screenshots.

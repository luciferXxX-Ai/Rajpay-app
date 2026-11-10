# Rajpay Android client (Flutter)

This is an Android app frontend for the independent FastAPI backend created earlier. It is not an official Rajpay app and does not connect to rajpay.store.

## Included screens
- Register / login (JWT stored locally)
- Product catalogue
- Create an order
- Initiate a simulated payment (no real charge)
- Order history
- User profile / logout

## Requirements
Install Flutter SDK and Android Studio (Android SDK + platform tools).

## Connect to backend
The backend must be running and reachable by the phone.
- Android emulator: `http://10.0.2.2:8000`
- Physical Android phone: use your computer's LAN IP, e.g. `http://192.168.1.10:8000` (phone and computer on same Wi-Fi).
- Production: use a deployed HTTPS API domain.

Build with a custom API URL:
```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000
```

For a physical phone, replace the URL:
```bash
flutter run --dart-define=API_URL=http://YOUR_PC_LAN_IP:8000
```

## Build APK
```bash
flutter pub get
flutter build apk --release --dart-define=API_URL=https://YOUR-HTTPS-API-DOMAIN
```
APK output:
`build/app/outputs/flutter-apk/app-release.apk`

## Important
- `usesCleartextTraffic=true` is enabled only to make local HTTP development easier. Remove it for production and use HTTPS.
- The backend payment endpoint is mock-only. No real money is charged.
- The backend must be accessible from the device; `localhost` on a phone refers to the phone itself, not your computer.
- This starter app does not yet include a wallet balance, real payment gateway, push notifications, or an admin UI.

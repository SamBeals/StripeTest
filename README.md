# StripeTest

Simple SwiftUI mock UI for an M2 Reader flow.

## Status

The app now supports a real Stripe Terminal integration when `AppConfig.readerMode` is set to `.stripeTerminal`. It uses the Stripe Terminal SDK to discover, connect, and collect payments with an M2 reader.

## Editing tips

- The main screen lives in `StripeTestApp/ContentView.swift`. Each section is a small computed view, so you can edit them one at a time.
- App state and button behavior live in `StripeTestApp/ContentViewModel.swift`.
- Reader interactions (mock vs real) are defined in `StripeTestApp/ReaderService.swift`.
- Environment-specific values (backend URL, location ID) live in `StripeTestApp/AppConfig.swift`.

## What is needed for real reader connectivity

- The repo now includes a `Package.swift` that pulls in the Stripe Terminal iOS SDK via Swift Package Manager. If you use Xcode, you can also add the same package in the project settings.
- Provide a backend endpoint that returns connection tokens for the SDK.
- Implement backend endpoints for creating payment intents and refunds.
- Handle required iOS permissions (Bluetooth, local network, location if needed).

The iOS code expects these backend endpoints under `AppConfig.backendURL`:

- `POST /connection_token` → `{ "secret": "..." }`
- `POST /create_payment_intent` → `{ "clientSecret": "..." }`
- `POST /refund` → `{ "paymentIntentId": "pi_..." }`

## Required account + location details for real connections

To connect to a live reader you will need:

- Stripe account credentials (publishable key + a backend secret key for connection tokens).
- The reader location ID used when registering the M2 reader in the Stripe Dashboard.
- A backend service that can create connection tokens scoped to the location.

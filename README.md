# StripeTest

Simple SwiftUI mock UI for an M2 Reader flow.

## Status

The current UI uses a mocked reader service. It does **not** connect to real Stripe Terminal hardware until the Stripe Terminal SDK is integrated.

## Editing tips

- The main screen lives in `StripeTestApp/ContentView.swift`. Each section is a small computed view, so you can edit them one at a time.
- App state and button behavior live in `StripeTestApp/ContentViewModel.swift`.
- Reader interactions (mock vs real) are defined in `StripeTestApp/ReaderService.swift`.
- Environment-specific values (backend URL, location ID) live in `StripeTestApp/AppConfig.swift`.

## What is still needed for real reader connectivity

- Add the Stripe Terminal iOS SDK and configure it with your Stripe account keys.
- Provide a backend endpoint that returns connection tokens for the SDK.
- Implement reader discovery, selection, and connection flows.
- Handle required iOS permissions (Bluetooth, local network, location if needed).

## Required account + location details for real connections

To connect to a live reader you will need:

- Stripe account credentials (publishable key + a backend secret key for connection tokens).
- The reader location ID used when registering the M2 reader in the Stripe Dashboard.
- A backend service that can create connection tokens scoped to the location.

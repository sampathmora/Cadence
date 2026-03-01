# Cadence

A minimal iOS app for tracking heart rate zones and daily steps using HealthKit.

## Features

- **Dashboard** — Today's step count with progress ring and heart rate zone breakdown
- **Steps** — 7-day bar chart with weekly totals, daily average, best day, and adjustable daily goal
- **Zones** — Create, edit, and delete custom heart rate zones with weekly target minutes and progress tracking

## Requirements

- iOS 17.6+
- iPhone or iPad
- Apple Watch or another heart rate source (for zone data)

## Tech Stack

- SwiftUI
- HealthKit
- Swift Charts
- `@Observable` (Observation framework)

## Privacy

Cadence requests **read-only** access to:
- Step count
- Heart rate

No health data is written or shared outside the device.

## Getting Started

1. Clone the repo
   ```
   git clone https://github.com/sampathmora/Cadence.git
   ```
2. Open `Cadence.xcodeproj` in Xcode
3. Select your development team in **Signing & Capabilities**
4. Build and run on a physical device (HealthKit is not available on Simulator)

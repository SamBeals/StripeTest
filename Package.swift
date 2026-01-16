// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StripeTest",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "StripeTestApp", targets: ["StripeTestApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/stripe/stripe-terminal-ios", from: "4.2.0")
    ],
    targets: [
        .target(
            name: "StripeTestApp",
            dependencies: [
                .product(name: "StripeTerminal", package: "stripe-terminal-ios")
            ],
            path: "StripeTestApp"
        )
    ]
)

# WPM Speedometer

A macOS menu bar application that displays your words-per-minute (WPM) typing speed in real-time.

## Features

*   Real-time WPM calculation.
*   2-second rolling window for accurate WPM updates.
*   High-frequency monitoring (50 updates per second).
*   Exclusion of modifier keys and keyboard shortcuts.
*   Menu bar display for convenient access.
*   Simple and lightweight design.

## Usage

1.  Download and install the application.
2.  Launch the app (it runs in the background).
3.  Your WPM will be displayed in the macOS menu bar.

## Installation

1.  Clone the repository: `git clone <repository_url>`
2.  Open the `wpm-speedometer.xcodeproj` file in Xcode.
3.  Build and run the application.

## Technologies Used

*   **SwiftUI:**  Used for the user interface (menu bar display).
*   **Swift:** The programming language used for the entire project.
*   **Cocoa:**  Provides access to macOS system features, including the global event tap for keystroke monitoring.
*   **Core Graphics:** Used for event handling.
*   **Xcode:**  The IDE (Integrated Development Environment) for building and running the macOS application.

## Testing

The project includes unit and UI tests:

*   **Unit Tests:** Located in the `wpm-speedometerTests` folder.  These tests focus on the core logic of the WPM calculation.
*   **UI Tests:** Located in the `wpm-speedometerUITests` folder. These tests check for the functionality and UI aspects of the application.


## Contributing

Contributions are welcome! Please open an issue or submit a pull request.



*README.md was made with [Etchr](https://etchr.dev)*
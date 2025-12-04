Prerequisites
Before starting, ensure you have Visual Studio Code installed.

Setup Instructions
Install the Flutter SDK Download and install the Flutter SDK for your operating system from the official website. Add it to your system PATH so you can run flutter commands.

Install VS Code Extensions Open VS Code. Click the Extensions icon (blocks on the left sidebar) and search for "Flutter". Install the official extension by the Flutter team (this automatically installs the Dart extension too).

Open the Project Unzip your project files. In VS Code, go to File > Open Folder... and select the folder containing pubspec.yaml (the root of your app).

Verify Installation Open the built-in Terminal (Ctrl + ~ or Terminal > New Terminal). Type flutter doctor and press Enter. Ensure there are checkmarks next to "Flutter" and "Chrome". Fix any issues listed if necessary.

Install Dependencies In the Terminal, run the following command to download the required packages (like firebase_auth, encrypt, etc.):

Bash

flutter pub get
Create Your Firebase Project Go to the Firebase Console.

Click Add project and name it (e.g., "secure-share-demo").

In the project dashboard, go to Build > Authentication and enable Email/Password.

Go to Build > Firestore Database and click Create Database (select Test Mode for now so it works immediately).

Connect Firebase to Your App

In your Firebase project overview, click the Web icon (</>) to add an app.

Copy the const firebaseConfig = { ... } content provided.

In VS Code, open lib/firebase_options.dart. Replace the values inside static const FirebaseOptions web = ... with the keys from your new project.

Select Target Device Look at the bottom-right corner of the VS Code window (the blue status bar). Click where it says "No Device" (or a device name) and select Chrome (web) from the list.

Note: This app uses dart:html so it must run on the Web.

Start Debugging Press F5 on your keyboard (or go to Run > Start Debugging) or use flutter run -d chrome

Test the App A Chrome window will launch running SecureShare.

Sign up with a fake email/password.

Upload a small text file (remember the limit is ~400KB).

Encrypt it with a passphrase and verify it appears in your list!
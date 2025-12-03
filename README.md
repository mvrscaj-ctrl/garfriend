SecureShare
SecureShare is a secure, intuitive data-sharing platform built with Flutter Web and Firebase. It emphasizes confidentiality and integrity by implementing client-side End-to-End Encryption (E2EE). Files are encrypted in the browser before ever reaching the server, ensuring that only users with the correct passphrase can access the data.

📋 Table of Contents
Features
Architecture & Security
Tech Stack
Getting Started
Usage Guide
Limitations & Roadmap
License

🚀 Features
End-to-End Encryption (E2EE): Files are encrypted/decrypted entirely on the client side using AES-GCM. The server never sees the plaintext or the key.
Granular Access Control: Share files securely with specific users via email allow-lists.
Audit Logging: Comprehensive, immutable logs for all actions (Upload, Share, Verify, Download, Delete) to ensure accountability.
Integrity Verification: The use of GCM (Galois/Counter Mode) ensures that file tampering is detected immediately upon decryption attempts.
Secure Storage: Only encrypted ciphertext and non-sensitive metadata are stored in the database.

🔒 Architecture & Security
SecureShare operates on a "Trust No One" (server-side) model.
Key Derivation:
The user provides a passphrase.
The app derives a 256-bit encryption key using SHA-256(passphrase).
Encryption (Upload):
A random 12-byte Initialization Vector (IV) is generated for every file.
The file is encrypted using AES-256-GCM.
The IV and Ciphertext (Base64 encoded) are uploaded to Cloud Firestore.
Decryption (Download):
The client downloads the IV and Ciphertext.
The user inputs the passphrase to re-derive the key.
The browser decrypts the data locally. If the data was tampered with on the server, GCM authentication fails.

🛠 Tech Stack
Component
Technology
Purpose
Frontend
Flutter (Web)
UI and client-side logic.
Auth
Firebase Auth
User identity management (Email/Password).
Database
Cloud Firestore
Storage of encrypted payloads and audit logs.
Cryptography
encrypt & crypto
Dart packages for AES-GCM and Hashing.

🏁 Getting Started
Prerequisites
Flutter SDK (Version 3.10.1 or higher)
A Firebase Project (Blaze plan not required for basic testing, but recommended).
Installation
Clone the repository:
git clone [https://github.com/yourusername/secure-share.git](https://github.com/yourusername/secure-share.git)
cd secure-share


Install dependencies:
flutter pub get


Firebase Configuration:
Create a project in the Firebase Console.
Enable Authentication (Email/Password provider).
Enable Cloud Firestore (Create database in test mode or set appropriate rules).
Run flutterfire configure OR manually place your firebase_options.dart file in lib/firebase_options.dart.
Run the App:
flutter run -d chrome


📖 Usage Guide
Sign Up/Login: Create an account using an email and password.
Upload File:
Enter a strong Passphrase.
Select a file (Note: Demo limit is ~400 KB).
Click Encrypt & save.
Share:
Go to "My encrypted files".
Click the Share icon and type the recipient's email address.
Download/Decrypt:
Enter the passphrase used to encrypt the file.
Click the Download icon. The file is decrypted in memory and saved to your device.

⚠️ Limitations & Roadmap
Current version is a Proof of Concept (PoC).
File Size Limit: Files are stored directly in Firestore documents as Base64 strings, limiting file size to approx. 400 KB.
Future: Move storage to Firebase Storage (Blob storage) to support large files.
Platform Support: Currently supports Web only due to dart:html usage for downloads.
Future: Implement file_saver or path_provider for Mobile/Desktop support.
Key Management: Keys are derived directly from passphrases without salting.
Future: Implement PBKDF2/Argon2 with random salts for stronger key derivation.

🤝 Contributing
Contributions are welcome! Please follow these steps:
Fork the project.
Create your feature branch (git checkout -b feature/AmazingFeature).
Commit your changes (git commit -m 'Add some AmazingFeature').
Push to the branch (git push origin feature/AmazingFeature).
Open a Pull Request.
📄 License
Distributed under the MIT License. See LICENSE for more information.

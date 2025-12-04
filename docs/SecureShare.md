Today we are presenting our project called SecureShare — an end-to-end encrypted file-sharing platform.
 We have developed this platform to allow users to upload, encrypt, share, and download files securely, even when the server cannot be trusted.
In this presentation, we will explain the problem we have addressed, the solution we’ve built, the technologies we have used, what the system does, and what we plan to improve in the future.”**

THE PROBLEM
**“We have begun this project by examining how traditional cloud services handle user data.
 Most platforms use server-side encryption, where the provider keeps the encryption keys.
 This has led to several risks:
Administrators can access user files.


A server breach exposes both the files and the keys.


Users must trust the service provider blindly.


We have wanted to remove this trust requirement completely, and give users full control over their own data.”**

OUR SOLUTION: TRUE END-TO-END ENCRYPTION
**“To solve this problem, we have designed a system based on true end-to-end encryption.
 All encryption happens on the client side — in the user’s browser — before anything is uploaded.
The server only stores encrypted data. It never sees the plaintext and never receives the encryption key.
 Even if the database is leaked, all attackers get is unreadable ciphertext.
This ‘Zero-Knowledge’ or ‘Trust No One’ approach has been the core philosophy behind SecureShare.”**


TECHNOLOGY STACK
**“To build SecureShare, we have used a simple but powerful open-source stack:
Flutter Web for the user interface


Firebase Authentication for login


Firestore for encrypted file storage and logging


AES-256-GCM for encryption


SHA-256 for key derivation


AES-GCM gives us both confidentiality and integrity, meaning any tampering is automatically detected.
By combining these technologies, we have created a system that is both secure and easy to use.”**

AUTHENTICATION & ACCESS CONTROL
**“We have implemented secure authentication using Firebase Auth.
 Users sign in with an email and password, and the system ensures that only logged-in users can access any features.
Access control is handled through email allow-lists.
 Users only see the files they own or files shared with them.
 This gives us a clear and secure permission structure.”**


HOW ENCRYPTION WORKS
**“Here is how encryption works when a user uploads a file:
The user enters a passphrase.


The system derives a 256-bit key using SHA-256.


A random IV is generated.


The file is encrypted locally with AES-GCM.


Only the ciphertext and IV are uploaded.


We have designed the system so the plaintext file never leaves the device, and the key is never sent anywhere.
 This ensures true end-to-end encryption."**

DEMO / USER EXPERIENCE 
**“Now let’s walk through the user interface of SecureShare.
When a user opens the app, they first see a clean login screen.
 After signing in, they land on the main dashboard.
Here the user can:
– Enter a passphrase
 – Select a file
 – Encrypt and upload it
 – Share it with other users
 – Download and decrypt files
 – Check the audit log
The dashboard shows two lists:
 ‘My encrypted files’ and ‘Files shared with me.’
 Each file displays metadata such as size, owner, creation time, and options for verifying decryption, sharing, downloading, or deleting.
Overall, the UI makes the entire process simple and intuitive, even for non-technical users.”**

FILE SHARING
**“When a user wants to share a file, they click the share icon and enter another user’s email address.
 The recipient is then added to the file’s sharedWith list in Firestore.
The important part is that this only allows access to the encrypted file — it does not share the passphrase.
 If the recipient doesn’t know the correct passphrase, they cannot decrypt the file.
So the system enforces both permission-based access and strong cryptographic protection.”**

DOWNLOADING & VERIFYING FILES
**“When downloading a file, the app fetches the encrypted data and asks the user for the passphrase again.
 The key is derived locally, and the file is decrypted in the browser.
If the encrypted data has been tampered with, AES-GCM detects it and decryption fails immediately.
We have also added a ‘Verify Decryption’ button that lets users test the passphrase without downloading the file.”**

AUDIT LOGGING
**“For accountability, we have implemented a full audit logging system.
Every important action is recorded:
Upload


Download


Share


Delete


Verify


Failed attempts


These logs are stored in a dedicated Firestore collection and displayed in the interface.
 This provides transparency and makes it easy to review who has done what.”**

SECURITY ADVANTAGES
**“Through our design, we have achieved several important security goals:
Only users hold the keys — not the server.


Data integrity is guaranteed through AES-GCM.


Access control restricts visibility.


The server remains blind — it handles only encrypted data.


Audit logs provide full traceability.


These features make SecureShare significantly more secure than traditional cloud storage.”**

LIMITATIONS
**“Because this project has been a proof-of-concept, we have had some limitations:
Firestore has a document size limit of about 400 KB


We have used SHA-256 directly for key derivation, without salting


The project currently runs best on the web because the download process depends on browser APIs


These limitations have been expected, and we have planned improvements to address them.”**


FUTURE ROADMAP
**“In the future, we will expand SecureShare in several ways:
– Move large files to Firebase Storage
 – Use PBKDF2 or Argon2 for stronger key derivation
 – Add RSA or ECC for secure key exchange
 – Build native mobile and desktop versions using Flutter
 – Implement per-file encryption keys
 – Improve the user-role system
These upgrades will allow SecureShare to evolve into a full production-ready system.”**

CONCLUSION
**“To conclude, SecureShare has demonstrated a working and secure end-to-end encrypted file-sharing platform.
 We have built a system where encryption always happens on the client, where only users hold their keys, and where the server never sees private data.
We have combined modern cryptography, usability, strong access control, and transparent logging to create a powerful security-focused application.
Thank you for listening, and we are happy to answer any questions.”**


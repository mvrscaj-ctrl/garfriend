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


Conclusion
SecureShare demonstrates a functional, user-friendly approach to secure document sharing using Flutter Web and Firebase. The architecture successfully integrates client-side encryption, granular access control, and audit logging while providing a minimalistic and intuitive interface.
Although security can be further improved—particularly around key derivation, validation, and platform compatibility—the project already offers a solid foundation for an educational or prototype end-to-end encrypted sharing platform.

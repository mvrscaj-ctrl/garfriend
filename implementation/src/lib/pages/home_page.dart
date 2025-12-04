import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html; // for web download

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ====== AUDIT LOGGING ======

  Future<void> _logEvent({
    required String fileId,
    required String eventType, // upload/share/verify/download/delete
    required String message,
    String? fileName,
    String? ownerId,
    String? ownerEmail,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('fileLogs').add({
        'fileId': fileId,
        'fileName': fileName,
        'eventType': eventType,
        'message': message,
        'actorId': user.uid,
        'actorEmail': user.email,
        'ownerId': ownerId ?? user.uid,
        'ownerEmail': ownerEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Logging failures should never break the app – ignore errors here
    }
  }

  final _passphraseController = TextEditingController(
    text: 'super_secret_passphrase',
  );
  PlatformFile? _selectedFile;
  String? _status;
  String? _error;
  bool _uploading = false;

  // Firestore document size limit is 1 MB. With metadata + base64 overhead,
  // we keep payload under ~400 KB to be safe.
  static const int maxFileSizeBytes = 400 * 1024; // ~400 KB

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  // ====== CRYPTO HELPERS (AES-GCM, SHA-256 key derivation) ======

  enc.Key _deriveKey(String passphrase) {
    final bytes = utf8.encode(passphrase);
    final hash = sha256.convert(bytes).bytes;
    return enc.Key(Uint8List.fromList(hash)); // 32 bytes = AES-256
  }

  /// Encrypt bytes with AES-GCM and return (iv, cipher) as base64 strings.
  Map<String, String> _encryptBytes(Uint8List data, String passphrase) {
    final key = _deriveKey(passphrase);
    final iv = enc.IV.fromSecureRandom(12); // 12-byte IV for GCM
    final encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.gcm),
    ); // AES-GCM

    final encrypted = encrypter.encryptBytes(data, iv: iv);

    return {
      'iv': base64Encode(iv.bytes),
      'cipher': base64Encode(encrypted.bytes),
    };
  }

  Uint8List _decryptBytes(String ivB64, String cipherB64, String passphrase) {
    final key = _deriveKey(passphrase);
    final ivBytes = base64Decode(ivB64);
    final cipherBytes = base64Decode(cipherB64);

    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(
      enc.AES(key, mode: enc.AESMode.gcm),
    ); // AES-GCM

    final encrypted = enc.Encrypted(cipherBytes);
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    return Uint8List.fromList(decrypted);
  }

  // ====== FILE PICK + ENCRYPT & SAVE (FIRESTORE) ======

  Future<void> _pickFile() async {
    setState(() {
      _error = null;
      _status = null;
      _selectedFile = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _error = 'No file selected.';
        });
        return;
      }

      final file = result.files.single;

      if (file.bytes == null) {
        setState(() {
          _error = 'Platform did not provide in-memory bytes for file.';
        });
        return;
      }

      if (file.size > maxFileSizeBytes) {
        setState(() {
          _error =
              'File too large for Firestore demo. Max ~400 KB, selected ${file.size} bytes.';
        });
        return;
      }

      setState(() {
        _selectedFile = file;
        _status = 'Selected: ${file.name} (${file.size} bytes)';
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to pick file: $e';
      });
    }
  }

  Future<void> _encryptAndSave() async {
    final user = FirebaseAuth.instance.currentUser;
    final file = _selectedFile;
    final passphrase = _passphraseController.text;

    setState(() {
      _error = null;
      _status = null;
    });

    if (user == null) {
      setState(() {
        _error = 'Not authenticated.';
      });
      return;
    }

    if (file == null || file.bytes == null) {
      setState(() {
        _error = 'Select a file first.';
      });
      return;
    }

    if (passphrase.isEmpty) {
      setState(() {
        _error = 'Passphrase cannot be empty.';
      });
      return;
    }

    try {
      setState(() {
        _uploading = true;
        _status = 'Encrypting file on client...';
      });

      final bundle = _encryptBytes(file.bytes!, passphrase);
      final ivB64 = bundle['iv']!;
      final cipherB64 = bundle['cipher']!;

      setState(() {
        _status = 'Saving encrypted file to Firestore...';
      });

      final filesRef = FirebaseFirestore.instance.collection('files');
      final fileDoc = filesRef.doc();

      await fileDoc.set({
        'ownerId': user.uid,
        'ownerEmail': user.email,
        'fileName': file.name,
        'fileSizeOriginal': file.size,
        'cipherSizeBase64': cipherB64.length,
        'iv': ivB64,
        'cipher': cipherB64,
        'sharedWith': <String>[], // STEP 1: sharing list
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _logEvent(
        fileId: fileDoc.id,
        eventType: 'upload',
        message: 'Encrypted & saved file.',
        fileName: file.name,
        ownerId: user.uid,
        ownerEmail: user.email,
      );

      setState(() {
        _uploading = false;
        _selectedFile = null;
        _status = 'File encrypted and saved successfully.';
      });
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = 'Encrypt/save failed: $e';
      });
    }
  }

  // ====== VERIFY DECRYPTION ======

  Future<void> _verifyDecrypt(
    String docId,
    String ivB64,
    String cipherB64,
  ) async {
    final passphrase = _passphraseController.text;

    setState(() {
      _error = null;
      _status = null;
    });

    if (passphrase.isEmpty) {
      setState(() {
        _error = 'Passphrase cannot be empty.';
      });
      return;
    }

    try {
      setState(() {
        _status = 'Decrypting file locally...';
      });

      final decryptedBytes = _decryptBytes(ivB64, cipherB64, passphrase);

      setState(() {
        _status =
            'Decryption OK for $docId. Decrypted size: ${decryptedBytes.length} bytes';
      });
      await _logEvent(
        fileId: docId,
        eventType: 'verify',
        message: 'Verified decryption with current passphrase.',
      );
    } catch (e) {
      setState(() {
        _error = 'Decryption failed. Wrong passphrase or corrupted data: $e';
      });
    }
  }

  // ====== STEP 2: DOWNLOAD DECRYPTED FILE ======

  void _downloadBytes(Uint8List data, String fileName) {
    final blob = html.Blob([data]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _downloadDecrypted(
    String docId,
    String fileName,
    String ivB64,
    String cipherB64,
  ) async {
    final passphrase = _passphraseController.text;

    setState(() {
      _error = null;
      _status = null;
    });

    if (passphrase.isEmpty) {
      setState(() {
        _error = 'Passphrase cannot be empty.';
      });
      return;
    }

    try {
      setState(() {
        _status = 'Decrypting & preparing download...';
      });

      final decrypted = _decryptBytes(ivB64, cipherB64, passphrase);

      _downloadBytes(decrypted, fileName);

      setState(() {
        _status = 'Decrypted file downloaded: $fileName';
      });
      await _logEvent(
        fileId: docId,
        eventType: 'download',
        message: 'Downloaded decrypted file $fileName.',
        fileName: fileName,
      );
    } catch (e) {
      setState(() {
        _error =
            'Download/decrypt failed. Wrong passphrase or corrupted data: $e';
      });
    }
  }

  // ====== STEP 1: SHARING ======

  Future<void> _shareFile(
    String docId,
    List<String> currentSharedWith,
    String fileName,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not authenticated.';
      });
      return;
    }

    final emailController = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share file with user'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Recipient email'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(emailController.text.trim()),
              child: const Text('Share'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) {
      return;
    }

    final normalized = result.toLowerCase();

    try {
      await FirebaseFirestore.instance.collection('files').doc(docId).update({
        'sharedWith': FieldValue.arrayUnion([normalized]),
      });
      await _logEvent(
        fileId: docId,
        eventType: 'share',
        message: 'Shared with $normalized',
        fileName: fileName,
      );

      setState(() {
        _status = 'File shared with $normalized';
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to share file: $e';
      });
    }
  }

  // ====== STEP 3: DELETE FILE ======

  Future<void> _deleteFile(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file'),
        content: const Text(
          'Are you sure you want to delete this encrypted file?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('files').doc(docId).delete();

      setState(() {
        _status = 'File deleted.';
      });
      await _logEvent(
        fileId: docId,
        eventType: 'delete',
        message: 'Deleted encrypted file.',
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to delete file: $e';
      });
    }
  }

  // ====== UI ======

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email?.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureShare – Files (Firestore demo)'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(child: Text(user.email ?? '')),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'End-to-end encrypted file sharing (AES-GCM, Firestore storage)',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Files are encrypted on the client with AES-GCM using a key derived '
                    'from the passphrase. Only base64 ciphertext + IV and metadata are '
                    'stored in Firestore. Demo file size is limited to ~400 KB.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passphraseController,
                    decoration: const InputDecoration(
                      labelText: 'Passphrase / shared secret',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Select file (max ~400 KB for demo)'),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedFile != null)
                        Expanded(
                          child: Text(
                            '${_selectedFile!.name} (${_selectedFile!.size} bytes)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _uploading ? null : _encryptAndSave,
                    icon: const Icon(Icons.lock),
                    label: _uploading
                        ? const Text('Encrypting & saving...')
                        : const Text('Encrypt & save to DB'),
                  ),
                  const SizedBox(height: 12),
                  if (_status != null)
                    Text(_status!, style: const TextStyle(color: Colors.green)),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const Divider(height: 32),
                  Text(
                    'My encrypted files',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildOwnedFilesList(user?.uid),
                  const SizedBox(height: 24),
                  Text(
                    'Files shared with me',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildSharedWithMeList(userEmail),
                  const SizedBox(height: 24),
                  Text(
                    'Recent activity (audit log)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildActivityLog(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----- My own files -----

  Widget _buildOwnedFilesList(String? uid) {
    if (uid == null) {
      return const Text('Not authenticated.');
    }

    final query = FirebaseFirestore.instance
        .collection('files')
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error loading files: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No files uploaded yet.'),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final fileName = data['fileName'] as String? ?? 'Unknown';
            final fileSizeOriginal = data['fileSizeOriginal'] as int? ?? 0;
            final cipherSize = data['cipherSizeBase64'] as int? ?? 0;
            final ivB64 = data['iv'] as String? ?? '';
            final cipherB64 = data['cipher'] as String? ?? '';
            final createdAt = data['createdAt'] as Timestamp?;
            final sharedWith = (data['sharedWith'] as List<dynamic>? ?? [])
                .cast<String>();

            return ListTile(
              title: Text(fileName),
              subtitle: Text(
                'Original: $fileSizeOriginal bytes, '
                'encrypted (base64): $cipherSize chars\n'
                'Shared with: ${sharedWith.isEmpty ? 'nobody' : sharedWith.join(', ')}\n'
                'Created: ${createdAt != null ? createdAt.toDate() : 'unknown'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Verify decryption locally',
                    icon: const Icon(Icons.verified),
                    onPressed: () {
                      if (ivB64.isEmpty || cipherB64.isEmpty) {
                        setState(() {
                          _error = 'Invalid ciphertext data for this file.';
                        });
                        return;
                      }
                      _verifyDecrypt(doc.id, ivB64, cipherB64);
                    },
                  ),
                  IconButton(
                    tooltip: 'Download decrypted file',
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      if (ivB64.isEmpty || cipherB64.isEmpty) {
                        setState(() {
                          _error = 'Invalid ciphertext data for this file.';
                        });
                        return;
                      }
                      _downloadDecrypted(doc.id, fileName, ivB64, cipherB64);
                    },
                  ),
                  IconButton(
                    tooltip: 'Share file',
                    icon: const Icon(Icons.share),
                    onPressed: () => _shareFile(doc.id, sharedWith, fileName),
                  ),
                  IconButton(
                    tooltip: 'Delete file',
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteFile(doc.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ----- Files shared with me -----

  Widget _buildSharedWithMeList(String? userEmail) {
    if (userEmail == null) {
      return const Text('Not authenticated.');
    }

    final query = FirebaseFirestore.instance
        .collection('files')
        .where('sharedWith', arrayContains: userEmail)
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error loading shared files: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No files shared with you yet.'),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final fileName = data['fileName'] as String? ?? 'Unknown';
            final ownerEmail = data['ownerEmail'] as String? ?? 'Unknown owner';
            final fileSizeOriginal = data['fileSizeOriginal'] as int? ?? 0;
            final cipherSize = data['cipherSizeBase64'] as int? ?? 0;
            final ivB64 = data['iv'] as String? ?? '';
            final cipherB64 = data['cipher'] as String? ?? '';
            final createdAt = data['createdAt'] as Timestamp?;

            return ListTile(
              title: Text(fileName),
              subtitle: Text(
                'Owner: $ownerEmail\n'
                'Original: $fileSizeOriginal bytes, encrypted (base64): $cipherSize chars\n'
                'Created: ${createdAt != null ? createdAt.toDate() : 'unknown'}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Verify decryption locally',
                    icon: const Icon(Icons.verified),
                    onPressed: () {
                      if (ivB64.isEmpty || cipherB64.isEmpty) {
                        setState(() {
                          _error = 'Invalid ciphertext data for this file.';
                        });
                        return;
                      }
                      _verifyDecrypt(doc.id, ivB64, cipherB64);
                    },
                  ),
                  IconButton(
                    tooltip: 'Download decrypted file',
                    icon: const Icon(Icons.download),
                    onPressed: () {
                      if (ivB64.isEmpty || cipherB64.isEmpty) {
                        setState(() {
                          _error = 'Invalid ciphertext data for this file.';
                        });
                        return;
                      }
                      _downloadDecrypted(doc.id, fileName, ivB64, cipherB64);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActivityLog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Text('Not authenticated.');
    }
    final uid = user.uid;

    final query = FirebaseFirestore.instance
        .collection('fileLogs')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error loading activity: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Filter to events where user is actor or owner
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final actorId = data['actorId'] as String?;
          final ownerId = data['ownerId'] as String?;
          return actorId == uid || ownerId == uid;
        }).toList();

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No recent activity yet.'),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final fileName = data['fileName'] as String? ?? '(unknown file)';
            final eventType = data['eventType'] as String? ?? 'event';
            final message = data['message'] as String? ?? '';
            final actorEmail = data['actorEmail'] as String? ?? '(unknown)';
            final createdAt = data['createdAt'] as Timestamp?;

            return ListTile(
              dense: true,
              title: Text('[$eventType] $fileName'),
              subtitle: Text(
                '$message\nBy: $actorEmail\n'
                'When: ${createdAt != null ? createdAt.toDate() : 'unknown'}',
              ),
            );
          },
        );
      },
    );
  }
}

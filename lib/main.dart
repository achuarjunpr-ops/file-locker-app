import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:share_plus/share_plus.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  runApp(const FileLockerApp());
}

class FileLockerApp extends StatelessWidget {
  const FileLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Locker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
        ),
      ),
      home: const LockerScreen(),
    );
  }
}

class LockerScreen extends StatefulWidget {
  const LockerScreen({super.key});

  @override
  State<LockerScreen> createState() => _LockerScreenState();
}

class _LockerScreenState extends State<LockerScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  String? _selectedFilePath;
  String? _selectedFileName;
  String? _lastSavedFilePath;
  bool _isLoading = false;
  bool _useBiometric = false;

  Future<bool> _authenticateUser() async {
    if (!_useBiometric) return true;

    try {
      final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) return true;

      return await auth.authenticate(
        localizedReason: 'Fingerprint verify ചെയ്യുക',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return true;
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path!;
        _selectedFileName = result.files.single.name;
        _lastSavedFilePath = null;
      });
    }
  }

  Future<void> _processFile(bool isEncrypt) async {
    if (_selectedFilePath == null) {
      _showSnackBar('ആദ്യം ഒരു ഫയൽ തിരഞ്ഞെടുക്കുക!');
      return;
    }

    if (_passwordController.text.length < 4) {
      _showSnackBar('കുറഞ്ഞത് 4 അക്ക പാസ്‌വേഡ് നൽകുക!');
      return;
    }

    bool authenticated = await _authenticateUser();
    if (!authenticated) {
      _showSnackBar('Authentication പരാജയപ്പെട്ടു!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final keyString = _passwordController.text.padRight(32, '*').substring(0, 32);
      final key = enc.Key.fromUtf8(keyString);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final file = File(_selectedFilePath!);
      final bytes = await file.readAsBytes();

      Uint8List processedData;
      String newFileName;

      Directory? outputDir;
      if (Platform.isAndroid) {
        outputDir = Directory('/storage/emulated/0/Download');
        if (!await outputDir.exists()) {
          outputDir = await getExternalStorageDirectory();
        }
      } else {
        outputDir = await getApplicationDocumentsDirectory();
      }

      if (isEncrypt) {
        final iv = enc.IV.fromSecureRandom(16);
        final encrypted = encrypter.encryptBytes(bytes, iv: iv);
        processedData = Uint8List.fromList(iv.bytes + encrypted.bytes);
        newFileName = "LOCKED_${_selectedFileName}.enc";
      } else {
        final ivBytes = bytes.sublist(0, 16);
        final fileData = bytes.sublist(16);
        final decrypted = encrypter.decryptBytes(
          enc.Encrypted(Uint8List.fromList(fileData)),
          iv: enc.IV(Uint8List.fromList(ivBytes)),
        );
        processedData = Uint8List.fromList(decrypted);
        newFileName = _selectedFileName!.replaceAll("LOCKED", "").replaceAll(".enc", "");
        if (!newFileName.contains('.')) newFileName = "UNLOCKED_$newFileName";
      }

      final outputFile = File('${outputDir!.path}/$newFileName');
      await outputFile.writeAsBytes(processedData);

      setState(() {
        _lastSavedFilePath = outputFile.path;
        _isLoading = false;
      });

      _showSnackBar(isEncrypt ? 'ഫയൽ എൻക്രിപ്റ്റ് ചെയ്തു Downloads-ൽ സേവ് ചെയ്തു!' : 'ഫയൽ ഡീക്രിപ്റ്റ് ചെയ്തു സേവ് ചെയ്തു!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('തെറ്റായ പാസ്‌വേഡ് അല്ലെങ്കിൽ ഫയൽ!');
    }
  }

  void _shareFile() {
    if (_lastSavedFilePath != null) {
      Share.shareXFiles([XFile(_lastSavedFilePath!)], text: 'Secure File Locker വഴി അയച്ചത്');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure File Locker 🔐', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: Text(
                      _selectedFileName ?? 'Select File to Lock / Unlock',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6366F1)),
                      labelText: 'Secret Password / PIN',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use Fingerprint Security', style: TextStyle(fontSize: 14)),
                    secondary: const Icon(Icons.fingerprint, color: Color(0xFF6366F1)),
                    value: _useBiometric,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (bool value) {
                      setState(() {
                        _useBiometric = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _processFile(true),
                      icon: const Icon(Icons.lock),
                      label: const Text('ENCRYPT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _processFile(false),
                      icon: const Icon(Icons.lock_open),
                      label: const Text('DECRYPT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            if (_lastSavedFilePath != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _shareFile,
                icon: const Icon(Icons.share),
                label: const Text('Share File via WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

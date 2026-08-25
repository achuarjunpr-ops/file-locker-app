import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:share_plus/share_plus.dart';

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
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const LockerHomePage(),
    );
  }
}

class LockerHomePage extends StatefulWidget {
  const LockerHomePage({super.key});

  @override
  State<LockerHomePage> createState() => _LockerHomePageState();
}

class _LockerHomePageState extends State<LockerHomePage> {
  File? _selectedFile;
  String? _selectedFileName;
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _lastSavedFilePath;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _selectedFileName = result.files.single.name;
        _lastSavedFilePath = null;
      });
    }
  }

  Future<Directory> _getPublicDirectory() async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    return dir!;
  }

  enc.Key _deriveKey(String password) {
    String padded = password.padRight(32, '0').substring(0, 32);
    return enc.Key.fromUtf8(padded);
  }

  Future<void> _processFile({required bool isEncrypt}) async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ആദ്യം ഒരു ഫയൽ തിരഞ്ഞെടുക്കുക!')),
      );
      return;
    }

    String password = _passwordController.text.trim();
    if (password.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('പാസ്‌വേഡിൽ കുറഞ്ഞത് 4 അക്ഷരങ്ങൾ വേണം!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final key = _deriveKey(password);
      final iv = enc.IV.fromLength(16);
      final encrypter = enc.Encrypter(enc.AES(key));

      final outputDir = await _getPublicDirectory();
      String newFileName;
      List<int> processedData;

      if (isEncrypt) {
        final encrypted = encrypter.encryptBytes(bytes, iv: iv);
        processedData = iv.bytes + encrypted.bytes;
        newFileName = "LOCKED_${_selectedFileName}.enc";
      } else {
        final ivBytes = bytes.sublist(0, 16);
        final fileData = bytes.sublist(16);
        final decrypted = encrypter.decryptBytes(
          enc.Encrypted(Uint8List.fromList(fileData)),
          iv: enc.IV(Uint8List.fromList(ivBytes)),
        );
        processedData = decrypted;
        newFileName = selectedFileName!.replaceAll("LOCKED", "").replaceAll(".enc", "");
        if (!newFileName.contains('.')) newFileName = "UNLOCKED_$newFileName";
      }

      final outputFile = File('${outputDir.path}/$newFileName');
      await outputFile.writeAsBytes(processedData);

      setState(() {
        _lastSavedFilePath = outputFile.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEncrypt ? 'ഫയൽ എൻക്രിപ്റ്റ് ചെയ്തു Downloads-ൽ സേവ് ചെയ്തു!' : 'ഫയൽ ഡീക്രിപ്റ്റ് ചെയ്തു Downloads-ൽ സേവ് ചെയ്തു!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('പ്രക്രിയ പരാജയപ്പെട്ടു! തെറ്റായ പാസ്‌വേഡ് ആയിരിക്കാം.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _shareFile() {
    if (_lastSavedFilePath != null) {
      Share.shareXFiles([XFile(_lastSavedFilePath!)], text: 'ഇതാ ഞാൻ അയച്ച എൻക്രിപ്റ്റ് ചെയ്ത ഫയൽ!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Locker App', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2F45C5),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_selectedFileName ?? 'Select File to Lock/Unlock'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: 'Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 25),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _processFile(isEncrypt: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: const Text('ENCRYPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _processFile(isEncrypt: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: const Text('DECRYPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 35),
            if (_lastSavedFilePath != null)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    const Text('ഫയൽ Downloads ഫോൾഡറിൽ സേവ് ആയിട്ടുണ്ട്!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _shareFile,
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text('Share File via WhatsApp', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

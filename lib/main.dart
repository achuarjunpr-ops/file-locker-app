import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

void main() => runApp(const MaterialApp(
      home: FileLockerApp(),
      debugShowCheckedModeBanner: false,
    ));

class FileLockerApp extends StatefulWidget {
  const FileLockerApp({super.key});

  @override
  State<FileLockerApp> createState() => _FileLockerAppState();
}

class _FileLockerAppState extends State<FileLockerApp> {
  String? filePath;
  final TextEditingController passwordController = TextEditingController();
  String statusMessage = "";

  enc.Key _deriveKey(String password) {
    var bytes = sha256.convert(Uint8List.fromList(password.codeUnits)).bytes;
    return enc.Key(Uint8List.fromList(bytes));
  }

  final enc.IV iv = enc.IV.fromLength(16);

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        filePath = result.files.single.path;
        statusMessage = "ഫയൽ സെലക്ട് ചെയ്തു: ${result.files.single.name}";
      });
    }
  }

  Future<void> processFile(bool isEncrypt) async {
    if (filePath == null || passwordController.text.isEmpty) {
      setState(() => statusMessage = "ഫയലും പാസ്‌വേഡും നൽകുക!");
      return;
    }

    try {
      final file = File(filePath!);
      final fileBytes = await file.readAsBytes();
      final key = _deriveKey(passwordController.text);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      if (isEncrypt) {
        final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
        final outPath = "${filePath!}.enc";
        await File(outPath).writeAsBytes(encrypted.bytes);
        setState(() => statusMessage = "Success! Encrypted file:\n$outPath");
      } else {
        final decrypted = encrypter.decryptBytes(enc.Encrypted(fileBytes), iv: iv);
        final outPath = filePath!.endsWith(".enc")
            ? filePath!.substring(0, filePath!.length - 4)
            : "${filePath!}_decrypted";
        await File(outPath).writeAsBytes(decrypted);
        setState(() => statusMessage = "Success! Decrypted file:\n$outPath");
      }
    } catch (e) {
      setState(() => statusMessage = "Error: തെറ്റായ പാസ്‌വേഡ് അല്ലെങ്കിൽ ഫയൽ കറപ്റ്റാണ്!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("C++ File Locker App"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: pickFile,
              icon: const Icon(Icons.attach_file),
              label: const Text("Select File to Lock/Unlock"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(12)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => processFile(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Text("ENCRYPT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => processFile(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Text("DECRYPT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

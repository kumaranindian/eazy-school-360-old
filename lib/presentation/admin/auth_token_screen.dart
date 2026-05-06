import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

// TEMPORARY SCREEN FOR POSTMAN TESTING
// Remove this file after getting the auth token
class AuthTokenScreen extends StatefulWidget {
  const AuthTokenScreen({super.key});

  @override
  State<AuthTokenScreen> createState() => _AuthTokenScreenState();
}

class _AuthTokenScreenState extends State<AuthTokenScreen> {
  String _token = 'Loading...';
  String _email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _email = user.email ?? '';
        final idToken = await user.getIdToken();
        setState(() {
          _token = idToken;
          _isLoading = false;
        });
      } else {
        setState(() {
          _token = 'No user signed in';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _token = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToken() async {
    await Clipboard.setData(ClipboardData(text: _token));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token copied to clipboard!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Auth Token for Postman'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email: $_email',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Auth Token:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: SelectableText(
                      _token,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _copyToken,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Token'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Steps:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Copy the token above'),
                  const Text('2. Open Postman collection'),
                  const Text('3. Set authToken variable to the copied token'),
                  const Text('4. Run the Cloud Function requests'),
                  const SizedBox(height: 16),
                  const Text(
                    '⚠️ Remove this screen after getting the token',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
    );
  }
}

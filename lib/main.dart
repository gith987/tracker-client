import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// URL temporaire - sera remplacée par votre URL Firebase
String firebaseUrl = "https://MON-PROJET-DEFAULT-RTDB.firebaseio.com/";

void main() {
  runApp(const ClientApp());
}

class ClientApp extends StatelessWidget {
  const ClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracker Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const ClientHomeScreen(),
    );
  }
}

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  
  bool _estEnCours = false;
  String _statut = "Non démarré";
  Position? _dernierePosition;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _nomController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<Position?> _obtenirPosition() async {
    bool serviceActif = await Geolocator.isLocationServiceEnabled();
    if (!serviceActif) {
      setState(() => _statut = "Erreur: Activez la localisation GPS");
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _statut = "Erreur: Permission GPS refusée");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _statut = "Erreur: Permissions GPS bloquées");
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _envoyerPosition() async {
    if (_nomController.text.trim().isEmpty) {
      setState(() => _statut = "Entrez un nom pour cet appareil");
      return;
    }

    Position? pos = await _obtenirPosition();
    if (pos == null) return;

    _dernierePosition = pos;
    String nom = _nomController.text.trim();
    String idUnique = nom.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

    final now = DateTime.now();
    String horodatage = "${now.day}/${now.month}/${now.year} à ${now.hour}h${now.minute.toString().padLeft(2, '0')}";

    final mapData = {
      "nom": nom,
      "latitude": pos.latitude,
      "longitude": pos.longitude,
      "derniere_mise_a_jour": horodatage,
    };

    String urlBase = _urlController.text.trim().isEmpty 
        ? firebaseUrl 
        : _urlController.text.trim();

    if (!urlBase.endsWith('/')) {
      urlBase += '/';
    }

    try {
      final response = await http.put(
        Uri.parse('${urlBase}appareils/$idUnique.json'),
        body: json.encode(mapData),
      );

      if (response.statusCode == 200) {
        setState(() {
          _statut = "Dernier envoi réussi : $horodatage";
        });
      } else {
        setState(() {
          _statut = "Erreur serveur (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _statut = "Erreur réseau : $e";
      });
    }
  }

  void _demarrerSuivi() {
    if (_nomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un nom pour cet appareil.')),
      );
      return;
    }

    setState(() {
      _estEnCours = true;
      _statut = "Suivi activé - Envoi en cours...";
    });

    _envoyerPosition();

    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _envoyerPosition();
    });
  }

  void _arreterSuivi() {
    _timer?.cancel();
    setState(() {
      _estEnCours = false;
      _statut = "Suivi arrêté";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Émetteur GPS - Appareil'),
        backgroundColor: Colors.deepOrange.shade100,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cell_tower, size: 80, color: Colors.deepOrange),
            const SizedBox(height: 20),
            
            TextField(
              controller: _nomController,
              enabled: !_estEnCours,
              decoration: const InputDecoration(
                labelText: 'Nom de cet appareil',
                hintText: 'ex: Tablette Bureau, Laptop Noir...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.devices),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _urlController,
              enabled: !_estEnCours,
              decoration: const InputDecoration(
                labelText: 'URL Serveur Firebase (optionnel)',
                hintText: 'https://votre-projet.firebasedatabase.app',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: _estEnCours ? _arreterSuivi : _demarrerSuivi,
              icon: Icon(_estEnCours ? Icons.stop : Icons.play_arrow),
              label: Text(_estEnCours ? 'Arrêter le suivi' : 'Démarrer le suivi'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: _estEnCours ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),

            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statut de l\'appareil :',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statut,
                      style: TextStyle(
                        color: _estEnCours ? Colors.green.shade800 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_dernierePosition != null) ...[
                      const Divider(),
                      Text('Latitude : ${_dernierePosition!.latitude}'),
                      Text('Longitude : ${_dernierePosition!.longitude}'),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

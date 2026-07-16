import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/strings.dart';
import '../../core/models/incident_model.dart';
import '../auth/auth_provider.dart';
import '../../core/services/incident_service.dart';
import '../../core/services/offline_queue_service.dart';

class ProofUploadScreen extends ConsumerStatefulWidget {
  final IncidentModel incident;
  const ProofUploadScreen({super.key, required this.incident});

  @override
  ConsumerState<ProofUploadScreen> createState() => _ProofUploadScreenState();
}

class _ProofUploadScreenState extends ConsumerState<ProofUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;

  bool _isUploading = false;
  String _uploadStatus = '';

  List<Map<String, dynamic>> _submittedProofs = [];
  bool _isLoadingProofs = true;

  @override
  void initState() {
    super.initState();
    _fetchSubmittedProofs();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _fetchSubmittedProofs() async {
    final token = ref.read(authProvider).token;
    final user = ref.read(authProvider).user;
    if (token == null || user == null) return;

    try {
      final result = await IncidentService.getProofs(
        token: token,
        incidentId: widget.incident.id,
      );

      if (mounted) {
        setState(() {
          if (result.success && result.data != null) {
            _submittedProofs = (result.data as List).cast<Map<String, dynamic>>().where((p) => p['operator_id'] == user.id).toList();
          }
          _isLoadingProofs = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching proofs: $e');
      if (mounted) {
        setState(() => _isLoadingProofs = false);
      }
    }
  }

  Future<Position?> _getGeostampSilently() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Location services are disabled. Cannot capture proof.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permissions are denied. Cannot capture proof.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('Location permissions are permanently denied.');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      _showError('Failed to acquire location.');
      return null;
    }
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String model = 'Unknown';
    String os = 'Unknown';

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        model = '${androidInfo.brand} ${androidInfo.model}';
        os = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        model = iosInfo.utsname.machine;
        os = 'iOS ${iosInfo.systemVersion}';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    return {'model': model, 'os': os};
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _captureAndUploadMedia(String type) async {
    // 1. Instantly start fetching location in the background
    final positionFuture = _getGeostampSilently();

    XFile? file;
    if (type == 'IMAGE') {
      file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    } else if (type == 'VIDEO') {
      file = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 2));
    }

    if (file == null) return;

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Acquiring secure location...';
    });

    // 2. Wait for the background location to finish (often already done!)
    final position = await positionFuture;
    if (position == null) {
      setState(() => _isUploading = false);
      return;
    }

    await _processUpload(
      type: type,
      file: File(file.path),
      position: position,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<Position?>? _audioPositionFuture;
  String? _recordingTimestamp;

  Future<void> _toggleAudioRecording() async {
    if (_isRecording) {
      // Stop
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      
      if (path != null && _audioPath != null && _audioPositionFuture != null) {
        setState(() {
          _isUploading = true;
          _uploadStatus = 'Acquiring secure location...';
        });

        // Await the location future we started when they clicked "record"
        final position = await _audioPositionFuture!;
        if (position != null) {
           await _processUpload(
             type: 'AUDIO',
             file: File(path),
             position: position,
             timestamp: _recordingTimestamp!,
           );
        } else {
           setState(() => _isUploading = false);
        }
      }
    } else {
      // Start
      if (await _audioRecorder.hasPermission()) {
        // Start background location fetch instantly!
        _audioPositionFuture = _getGeostampSilently();

        final path = '${Directory.systemTemp.path}/record_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordingTimestamp = DateTime.now().toUtc().toIso8601String();
        
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        setState(() {
          _isRecording = true;
          _audioPath = path;
        });
      } else {
        _showError('Microphone permission denied.');
      }
    }
  }

  Future<void> _captureTextStatement() async {
    // Start getting location instantly
    final positionFuture = _getGeostampSilently();
    
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final textController = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Text Statement', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: textController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter your official statement here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (submit == true && textController.text.trim().isNotEmpty) {
      setState(() {
        _isUploading = true;
        _uploadStatus = 'Acquiring secure location...';
      });

      final position = await positionFuture;
      if (position != null) {
        await _processUpload(
          type: 'TEXT',
          textContent: textController.text.trim(),
          position: position,
          timestamp: timestamp,
        );
      } else {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _processUpload({
    required String type,
    File? file,
    String? textContent,
    required Position position,
    required String timestamp,
  }) async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading proof...';
    });

    try {
      final token = ref.read(authProvider).token;
      if (token == null) return;
      
      final deviceInfo = await _getDeviceInfo();
      final uploadId = const Uuid().v4();

      bool isOffline = false;
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (!connectivityResult.contains(ConnectivityResult.mobile) && !connectivityResult.contains(ConnectivityResult.wifi)) {
          isOffline = true;
        } else {
          try {
            final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
            if (result.isEmpty || result[0].rawAddress.isEmpty) {
              isOffline = true;
            }
          } on SocketException catch (_) {
            isOffline = true;
          } on TimeoutException catch (_) {
            isOffline = true;
          }
        }
      } catch (_) {}

      String? permanentFilePath;
      if (file != null && await file.exists()) {
        final dir = await getApplicationDocumentsDirectory();
        final ext = p.extension(file.path);
        final newPath = p.join(dir.path, 'proof_${DateTime.now().millisecondsSinceEpoch}$ext');
        final permanentFile = await file.copy(newPath);
        permanentFilePath = permanentFile.path;
      }

      if (isOffline) {
        await OfflineQueueService().insertMedia({
          'incident_id': widget.incident.id,
          'proof_type': type,
          'file_path': permanentFilePath,
          'text_content': textContent,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': timestamp,
          'device_model': deviceInfo['model'],
          'device_os': deviceInfo['os'],
          'status': 'pending',
          'upload_id': uploadId,
        });
        
        if (mounted) {
          setState(() {
            _isUploading = false;
            _submittedProofs.insert(0, {
              'proof_type': type,
              'text_content': textContent,
              'timestamp': timestamp,
              'geostamp': {'lat': position.latitude, 'lng': position.longitude},
              'url': null, // indicate it's offline/local only
            });
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$type queued locally for sync.'), backgroundColor: AppColors.warning),
          );
        }
        return;
      }

      final result = await IncidentService.uploadProof(
        token: token,
        incidentId: widget.incident.id,
        proofType: type,
        filePath: permanentFilePath ?? file?.path,
        textContent: textContent,
        timestamp: timestamp,
        geostamp: {
          'lat': position.latitude,
          'lng': position.longitude,
        },
        deviceInfo: deviceInfo,
        uploadId: uploadId,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          if (result.success && result.data != null) {
            _submittedProofs.insert(0, result.data!['proof']);
          }
        });
        
        if (result.success) {
          if (permanentFilePath != null) {
            final f = File(permanentFilePath);
            if (await f.exists()) await f.delete();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$type uploaded successfully.'), backgroundColor: AppColors.success),
          );
        } else if (result.message == AppStrings.networkError) {
          // Fallback if it failed due to network
          await OfflineQueueService().insertMedia({
            'incident_id': widget.incident.id,
            'proof_type': type,
            'file_path': permanentFilePath,
            'text_content': textContent,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': timestamp,
            'device_model': deviceInfo['model'],
            'device_os': deviceInfo['os'],
            'status': 'pending',
            'upload_id': uploadId,
          });
          setState(() {
            _submittedProofs.insert(0, {
              'proof_type': type,
              'text_content': textContent,
              'timestamp': timestamp,
              'geostamp': {'lat': position.latitude, 'lng': position.longitude},
              'url': null, // local only
            });
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$type queued locally (network error).'), backgroundColor: AppColors.warning),
          );
        } else {
          _showError(result.message ?? 'Failed to upload proof. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      _showError('Failed to upload proof. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Proof Upload', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_isUploading)
            Container(
              color: Colors.blue.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 16),
                  Text(_uploadStatus, style: GoogleFonts.poppins()),
                ],
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildCaptureButton('Photo', Icons.camera_alt_rounded, Colors.blue, () => _captureAndUploadMedia('IMAGE')),
                _buildCaptureButton('Video', Icons.videocam_rounded, Colors.red, () => _captureAndUploadMedia('VIDEO')),
                _buildCaptureButton(_isRecording ? 'Stop' : 'Audio', _isRecording ? Icons.stop_rounded : Icons.mic_rounded, _isRecording ? Colors.red : Colors.orange, _toggleAudioRecording),
                _buildCaptureButton('Text', Icons.text_snippet_rounded, Colors.green, _captureTextStatement),
              ],
            ),
          ),
          
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('My Submitted Proofs', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          ),

          Expanded(
            child: _isLoadingProofs
                ? const Center(child: CircularProgressIndicator())
                : _submittedProofs.isEmpty
                    ? Center(child: Text('No proofs submitted yet.', style: GoogleFonts.poppins(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _submittedProofs.length,
                        itemBuilder: (ctx, i) {
                          final p = _submittedProofs[i];
                          IconData icon;
                          switch (p['proof_type']) {
                            case 'IMAGE': icon = Icons.image; break;
                            case 'VIDEO': icon = Icons.movie; break;
                            case 'AUDIO': icon = Icons.audiotrack; break;
                            case 'TEXT': icon = Icons.text_snippet; break;
                            default: icon = Icons.insert_drive_file;
                          }
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              onTap: () async {
                                if (p['url'] != null) {
                                  final uri = Uri.parse(p['url']);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  } else {
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open media.')));
                                  }
                                }
                              },
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryNavy.withValues(alpha: 0.1),
                                child: Icon(icon, color: AppColors.primaryNavy),
                              ),
                              title: Text('${p['proof_type']} Proof', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (p['text_content'] != null)
                                    Text('"${p['text_content']}"', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontStyle: FontStyle.italic)),
                                  Text(
                                    '${DateTime.parse(p['timestamp']).toLocal().toString().split('.').first}\nLat: ${p['geostamp']['lat'].toStringAsFixed(4)}, Lng: ${p['geostamp']['lng'].toStringAsFixed(4)}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: p['url'] != null ? const Icon(Icons.open_in_new, size: 16) : null,
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: _isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartDoorbellApp());
}

class SmartDoorbellApp extends StatelessWidget {
  const SmartDoorbellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Doorbell',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          primary: const Color(0xFF2563EB),
          secondary: const Color(0xFF10B981),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

/// Mock Realtime Service for Doorbell Events
class DoorbellEvent {
  final String id;
  final DateTime timestamp;
  final String visitorNote;
  final String visitorImage;
  bool isAnswered;

  DoorbellEvent({
    required this.id,
    required this.timestamp,
    required this.visitorNote,
    required this.visitorImage,
    this.isAnswered = false,
  });
}

class DoorbellService extends ChangeNotifier {
  static final DoorbellService _instance = DoorbellService._internal();
  factory DoorbellService() => _instance;
  DoorbellService._internal();

  final List<DoorbellEvent> _history = [];
  DoorbellEvent? _activeIncomingRing;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRingingSoundPlaying = false;

  List<DoorbellEvent> get history => List.unmodifiable(_history);
  DoorbellEvent? get activeIncomingRing => _activeIncomingRing;
  bool get isRinging => _activeIncomingRing != null;

  void triggerRing({required String note, required String imagePlaceholder}) {
    final event = DoorbellEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      visitorNote: note,
      visitorImage: imagePlaceholder,
    );
    _activeIncomingRing = event;
    _history.insert(0, event);
    notifyListeners();

    _playDoorbellChime();
  }

  void answerRing() {
    if (_activeIncomingRing != null) {
      _activeIncomingRing!.isAnswered = true;
      _stopDoorbellChime();
      _activeIncomingRing = null;
      notifyListeners();
    }
  }

  void dismissRing() {
    _stopDoorbellChime();
    _activeIncomingRing = null;
    notifyListeners();
  }

  Future<void> _playDoorbellChime() async {
    try {
      _isRingingSoundPlaying = true;
      // In production Flutter, point to bundled asset: AssetSource('sounds/doorbell.mp3')
      // Or URL source for streaming:
      await _audioPlayer.play(
        UrlSource('https://cdn.freesound.org/previews/274/274178_5121236-lq.mp3'),
      );
    } catch (e) {
      debugPrint('Audio playback error: $e');
    }
  }

  Future<void> _stopDoorbellChime() async {
    try {
      _isRingingSoundPlaying = false;
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final DoorbellService _service = DoorbellService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (_service.isRinging && _currentIndex != 1) {
      // Show incoming call dialog if on another tab
      _showIncomingRingDialog(_service.activeIncomingRing!);
    }
    setState(() {});
  }

  void _showIncomingRingDialog(DoorbellEvent event) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.notifications_active, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('มีคนกดกริ่งหน้าบ้าน!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ข้อความ: ${event.visitorNote}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'เวลา: ${DateFormat('HH:mm:ss').format(event.timestamp)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _service.dismissRing();
            },
            child: const Text('ตัดสาย / ปิดเสียง', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _service.answerRing();
              setState(() {
                _currentIndex = 1; // Go to Friend screen
              });
            },
            icon: const Icon(Icons.videocam),
            label: const Text('ดูหน้าเพื่อน / รับสาย'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const VisitorDoorbellScreen(),
      const FriendDashboardScreen(),
      const HistoryLogScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.touch_app_outlined),
            selectedIcon: Icon(Icons.touch_app, color: Color(0xFF2563EB)),
            label: 'กริ่งหน้าบ้าน',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF2563EB)),
            label: 'เครื่องเพื่อน (เจ้าของบ้าน)',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFF2563EB)),
            label: 'ประวัติการกด',
          ),
        ],
      ),
    );
  }
}

/// SCREEN 1: Visitor Doorbell Screen (ฝั่งคนกดกริ่งหน้าบ้าน)
class VisitorDoorbellScreen extends StatefulWidget {
  const VisitorDoorbellScreen({super.key});

  @override
  State<VisitorDoorbellScreen> createState() => _VisitorDoorbellScreenState();
}

class _VisitorDoorbellScreenState extends State<VisitorDoorbellScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  String _selectedNote = 'เพื่อนมาหา 👋';
  bool _isRinging = false;
  final List<String> _quickNotes = [
    'เพื่อนมาหา 👋',
    'พัสดุมาส่ง 📦',
    'อาหารเดลิเวอรี 🛵',
    'ติดต่อด่วน 🔔',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _pressDoorbell() {
    setState(() => _isRinging = true);
    DoorbellService().triggerRing(
      note: _selectedNote,
      imagePlaceholder: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('กริ่งส่งสัญญาณไปที่เครื่องเพื่อนแล้ว!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isRinging = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('กริ่งหน้าบ้าน (Visitor)'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Camera Preview Frame
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=600&q=80',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                            SizedBox(width: 5),
                            Text('LIVE CAMERA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'กล้องหน้าบ้านกำลังจับภาพใบหน้าผู้มาเยือน',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Note selection
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('เลือกเหตุผลการกดกริ่ง:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickNotes.map((note) {
                  final isSelected = _selectedNote == note;
                  return ChoiceChip(
                    label: Text(note),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB).withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF2563EB) : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedNote = note);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 36),

              // Big Circular Bell Button
              GestureDetector(
                onTap: _pressDoorbell,
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    final scale = _isRinging ? 1.0 + (_animController.value * 0.08) : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isRinging
                                ? [const Color(0xFFF59E0B), const Color(0xFFEF4444)]
                                : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isRinging ? Colors.red : const Color(0xFF2563EB)).withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: _isRinging ? 8 : 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isRinging ? Icons.notifications_active : Icons.doorbell_outlined,
                              size: 58,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isRinging ? 'กำลังดัง...' : 'กดกริ่ง',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
              Text(
                _isRinging
                    ? '🔔 ส่งเสียงกริ่งไปดังที่เครื่องเพื่อนแล้ว!'
                    : 'แตะปุ่มด้านบนเพื่อส่งสัญญาณกริ่งพร้อมภาพใบหน้า',
                style: TextStyle(
                  color: _isRinging ? Colors.orange.shade800 : Colors.grey.shade600,
                  fontWeight: _isRinging ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SCREEN 2: Friend Dashboard Screen (ฝั่งเครื่องเพื่อน / เจ้าของบ้าน)
class FriendDashboardScreen extends StatefulWidget {
  const FriendDashboardScreen({super.key});

  @override
  State<FriendDashboardScreen> createState() => _FriendDashboardScreenState();
}

class _FriendDashboardScreenState extends State<FriendDashboardScreen> {
  bool _isIntercomActive = false;
  bool _isDoorUnlocked = false;

  @override
  Widget build(BuildContext context) {
    final service = DoorbellService();
    final activeRing = service.activeIncomingRing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('เครื่องเพื่อน (Host/Friend)'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: activeRing != null ? Colors.red.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: activeRing != null ? Colors.red.shade300 : Colors.blue.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: activeRing != null ? Colors.red : const Color(0xFF2563EB),
                      child: Icon(
                        activeRing != null ? Icons.notifications_active : Icons.check,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeRing != null ? 'มีคนกดกริ่งอยู่ตอนนี้!' : 'สถานะ: พร้อมรับสายกริ่งหน้าบ้าน',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: activeRing != null ? Colors.red.shade900 : Colors.blue.shade900,
                            ),
                          ),
                          Text(
                            activeRing != null
                                ? 'กำลังเล่นเสียงกริ่งและแสดงหน้าเพื่อน/ผู้กด'
                                : 'แอปกำลังดักฟังสัญญาณ Real-time',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Live Display of Visitor / Friend Face
              const Text(
                'จอแสดงผลใบหน้าคนกดกริ่ง:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),

              Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        activeRing?.visitorImage ??
                            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=600&q=80',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.signal_cellular_alt, color: Colors.greenAccent, size: 14),
                            const SizedBox(width: 4),
                            Text('1080p HD', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black87],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeRing != null ? 'เหตุผล: ${activeRing.visitorNote}' : 'หน้าบ้าน (Doorbell Front Gate)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              activeRing != null
                                  ? 'กดเมื่อ ${DateFormat('HH:mm:ss').format(activeRing.timestamp)}'
                                  : 'ตรวจจับใบหน้าอัตโนมัติ',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons (Intercom, Door Unlock, End Call)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isIntercomActive ? Colors.red : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        setState(() => _isIntercomActive = !_isIntercomActive);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isIntercomActive ? 'เปิดไมโครโฟนพูดคุยแล้ว 🎙️' : 'ปิดไมโครโฟน'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: Icon(_isIntercomActive ? Icons.mic : Icons.mic_none),
                      label: Text(_isIntercomActive ? 'กำลังคุย...' : 'พูดคุยโต้ตอบ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDoorUnlocked ? Colors.grey : Colors.emeraldColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        setState(() => _isDoorUnlocked = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ส่งคำสั่งปลดล็อกประตูหน้าบ้านแล้ว 🔓')),
                        );
                        Future.delayed(const Duration(seconds: 3), () {
                          if (mounted) setState(() => _isDoorUnlocked = false);
                        });
                      },
                      icon: Icon(_isDoorUnlocked ? Icons.lock_open : Icons.lock_outline),
                      label: Text(_isDoorUnlocked ? 'เปิดแล้ว' : 'ปลดล็อกประตู'),
                    ),
                  ),
                ],
              ),

              if (activeRing != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => service.dismissRing(),
                    icon: const Icon(Icons.call_end),
                    label: const Text('วางสาย / ปิดเสียงกริ่ง'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension ColorExtension on Colors {
  static const Color emeraldColor = Color(0xFF059669);
}

/// SCREEN 3: History Log Screen (บันทึกประวัติการกดกริ่ง)
class HistoryLogScreen extends StatelessWidget {
  const HistoryLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = DoorbellService().history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ประวัติการกดกริ่ง'),
        centerTitle: true,
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('ยังไม่มีประวัติการกดกริ่ง', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('เมื่อมีคนกดกริ่ง ระบบจะบันทึกเวลาและภาพไว้ที่นี่', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = history[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 1,
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.visitorImage,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(item.visitorNote, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm:ss').format(item.timestamp)),
                    trailing: Icon(
                      item.isAnswered ? Icons.check_circle : Icons.ring_volume,
                      color: item.isAnswered ? Colors.green : Colors.amber,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

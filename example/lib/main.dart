// lib/main.dart
import 'dart:async';
import 'package:cross_p2p_network/cross_p2p_network.dart';
import 'package:flutter/material.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TeacherHome(),
    );
  }
}

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  String _status = 'Not initialized';
  String? _roomId;
  String? _ssid;
  String? _password;
  final _classCodeController = TextEditingController(text: 'MATH101');
  final _subjectController = TextEditingController(text: 'Mathematics');
  late StreamSubscription<NetworkEvent> _eventSubscription;
  late StreamSubscription<Map<String, dynamic>> _dataSubscription;

  @override
  void initState() {
    super.initState();
    _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    try {
      await CrossP2PNetwork.initialize(
        serviceType: '_attendance._tcp',
        preferAware: true,
        enableDebugLogs: true,
      );
      setState(() => _status = 'Initialized');

      _eventSubscription = CrossP2PNetwork.getEventStream().listen((event) {
        setState(() => _status = 'Event: ${event.type} - ${event.message}');
      });
    } catch (e) {
      setState(() => _status = 'Init failed: $e');
    }
  }

  Future<void> _createRoom() async {
    try {
      final result = await CrossP2PNetwork.createRoom(
        classCode: _classCodeController.text,
        expectedSize: 50,
        subject: _subjectController.text,
        onDataReceived: (data) {
          // Handled via stream above
        },
        onQuizResponses: (responses) {
          // Optional: Handle quizzes
        },
      );
      if (result.success) {
        setState(() {
          _roomId = result.roomId;
          _ssid = result.ssid;
          _password = result.password;
          _status = 'Room created: ${_roomId}';
        });
      } else {
        setState(() => _status = 'Create failed: ${result.error}');
      }
    } catch (e) {
      setState(() => _status = 'Create error: $e');
    }
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _dataSubscription.cancel();
    CrossP2PNetwork.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Status: $_status'),
            TextField(
              controller: _classCodeController,
              decoration: const InputDecoration(labelText: 'Class Code'),
            ),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            ElevatedButton(onPressed: _createRoom, child: const Text('Create Room')),
            if (_ssid != null) Text('SSID: $_ssid \nPassword: $_password'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  String _status = 'Not initialized';
  final _studentIdController = TextEditingController(text: 'STU_12345');
  final _rollNoController = TextEditingController(text: 'CS001');
  final _nameController = TextEditingController(text: 'John Doe');
  final _emailController = TextEditingController(text: 'john@example.com');
  final _mobileController = TextEditingController(text: '+1234567890');
  late StreamSubscription<NetworkEvent> _eventSubscription;
  late StreamSubscription<Map<String, dynamic>> _dataSubscription;

  @override
  void initState() {
    super.initState();
    _initializePlugin();
  }

  Future<void> _initializePlugin() async {
    try {
      await CrossP2PNetwork.initialize(
        serviceType: '_attendance._tcp',
        preferAware: true,
        enableDebugLogs: true,
      );
      setState(() => _status = 'Initialized');

      _eventSubscription = CrossP2PNetwork.getEventStream().listen((event) {
        setState(() => _status = 'Event: ${event.type} - ${event.message}');
      });

      _dataSubscription = CrossP2PNetwork.getDataStream().listen((data) {
        // Handle received data, e.g., quizzes
        setState(() => _status = 'Received data: $data');
      });
    } catch (e) {
      setState(() => _status = 'Init failed: $e');
    }
  }

  Future<void> _scanAndJoin() async {
    try {
      final studentInfo = {
        'studentId': _studentIdController.text,
        'rollNo': _rollNoController.text,
        'studentName': _nameController.text,
        'studentEmail': _emailController.text,
        'studentMobile': _mobileController.text,
      };
      final result = await CrossP2PNetwork.scanAndJoin(
        studentId: _studentIdController.text,
        studentInfo: studentInfo,
        onDataReceived: (data) {
          // Handled via stream
        },
      );
      if (result.success) {
        setState(() => _status = 'Joined successfully');
        // Send attendance after join
        await CrossP2PNetwork.sendData({
          'action': 'attendance',
          'timestamp': DateTime.now().toIso8601String(),
          'location': 'Room 101',
          'studentName': _nameController.text,
        });
        await CrossP2PNetwork.sendHeartbeat();
      } else {
        setState(() => _status = 'Join failed: ${result.error}');
      }
    } catch (e) {
      setState(() => _status = 'Join error: $e');
    }
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _dataSubscription.cancel();
    CrossP2PNetwork.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Status: $_status'),
            TextField(controller: _studentIdController, decoration: const InputDecoration(labelText: 'Student ID')),
            TextField(controller: _rollNoController, decoration: const InputDecoration(labelText: 'Roll No')),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _mobileController, decoration: const InputDecoration(labelText: 'Mobile')),
            ElevatedButton(onPressed: _scanAndJoin, child: const Text('Scan and Join Room')),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
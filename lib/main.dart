import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const SuperSenhaApp());
}

class SuperSenhaApp extends StatelessWidget {
  const SuperSenhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Senha',
      theme: ThemeData.dark(),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const int rows = 6;
  static const int cols = 5;
  final List<List<String>> _board =
      List.generate(rows, (_) => List.filled(cols, ''));
  int _currentRow = 0;
  int _currentCol = 0;

  late Timer _timer;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    void update() {
      final now = DateTime.now();
      final nextMidnight = DateTime(now.year, now.month, now.day + 1);
      final remaining = nextMidnight.difference(now);
      final hours = remaining.inHours.remainder(24).toString().padLeft(2, '0');
      final minutes =
          remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
      final seconds =
          remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() {
        _countdown = '$hours:$minutes:$seconds';
      });
    }

    update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => update());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleKey(String key) {
    setState(() {
      if (key == 'ENTER') {
        if (_currentCol == cols) {
          _currentRow = (_currentRow + 1).clamp(0, rows - 1);
          _currentCol = 0;
        }
      } else if (key == 'BACK') {
        if (_currentCol > 0) {
          _currentCol--;
          _board[_currentRow][_currentCol] = '';
        }
      } else if (_currentCol < cols && key.length == 1) {
        _board[_currentRow][_currentCol] = key;
        _currentCol++;
      }
    });
  }

  void _resetGame() {
    setState(() {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          _board[r][c] = '';
        }
      }
      _currentRow = 0;
      _currentCol = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Senha'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Sobre', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                'Próxima palavra do dia em: $_countdown',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildBoard(),
          const SizedBox(height: 24),
          _buildKeyboard(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _resetGame,
            child: const Text('Jogar novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Column(
      children: List.generate(rows, (r) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cols, (c) {
            final letter = _board[r][c];
            return Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              alignment: Alignment.center,
              child: Text(letter.toUpperCase(),
                  style: const TextStyle(fontSize: 18)),
            );
          }),
        );
      }),
    );
  }

  Widget _buildKeyboard() {
    const letters = 'QWERTYUIOPASDFGHJKLZXCVBNM';
    final keys = [
      ...letters.split(''),
      'BACK',
      'ENTER',
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      children: keys.map((k) {
        return Padding(
          padding: const EdgeInsets.all(4),
          child: ElevatedButton(
            onPressed: () => _handleKey(k),
            child: Text(k.length == 1 ? k : (k == 'BACK' ? '⌫' : '⏎')),
          ),
        );
      }).toList(),
    );
  }
}

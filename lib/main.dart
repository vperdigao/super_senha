import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

enum LetterStatus { initial, correct, partial, wrong }

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
  late List<List<LetterStatus>> _status;
  int _currentRow = 0;
  int _currentCol = 0;

  List<String> _dictionary = [];
  String _secretWord = '';
  bool _gameOver = false;
  bool _won = false;

  late Timer _timer;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    _status =
        List.generate(rows, (_) => List.filled(cols, LetterStatus.initial));
    _loadDictionary().then((_) {
      _startCountdown();
    });
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

  Future<void> _loadDictionary() async {
    final data = await rootBundle.loadString('assets/words.json');
    final List<dynamic> words = json.decode(data);
    _dictionary = words.map((w) => w.toString().toUpperCase()).toList();

    final today = DateTime.now();
    final index = today.difference(DateTime(2022)).inDays % _dictionary.length;
    setState(() {
      _secretWord = _dictionary[index];
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleKey(String key) {
    if (_gameOver) return;
    setState(() {
      if (key == 'ENTER') {
        if (_currentCol == cols) {
          _submitGuess();
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
      _status =
          List.generate(rows, (_) => List.filled(cols, LetterStatus.initial));
      _gameOver = false;
      _won = false;
      _secretWord =
          _dictionary[(DateTime.now().millisecondsSinceEpoch) % _dictionary.length];
    });
  }

  void _submitGuess() {
    final guess = _board[_currentRow].join().toUpperCase();
    if (!_dictionary.contains(guess)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Palavra inválida')),
      );
      return;
    }

    for (var i = 0; i < cols; i++) {
      final letter = guess[i];
      if (letter == _secretWord[i]) {
        _status[_currentRow][i] = LetterStatus.correct;
      } else if (_secretWord.contains(letter)) {
        _status[_currentRow][i] = LetterStatus.partial;
      } else {
        _status[_currentRow][i] = LetterStatus.wrong;
      }
    }

    if (guess == _secretWord) {
      _gameOver = true;
      _won = true;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Você acertou!'),
          content: Text('A palavra correta é $_secretWord'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } else if (_currentRow == rows - 1) {
      _gameOver = true;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Não foi desta vez'),
          content: Text('A palavra correta era $_secretWord'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } else {
      _currentRow++;
      _currentCol = 0;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Super Senha '),
            Icon(_won ? Icons.lock_open : Icons.lock),
          ],
        ),
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
            final status = _status[r][c];
            Color bgColor;
            switch (status) {
              case LetterStatus.correct:
                bgColor = Colors.green;
                break;
              case LetterStatus.partial:
                bgColor = Colors.yellow;
                break;
              case LetterStatus.wrong:
                bgColor = Colors.grey.shade800;
                break;
              default:
                bgColor = Colors.transparent;
            }
            return Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                color: bgColor,
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
            onPressed: _gameOver ? null : () => _handleKey(k),
            child: Text(k.length == 1 ? k : (k == 'BACK' ? '⌫' : '⏎')),
          ),
        );
      }).toList(),
    );
  }
}

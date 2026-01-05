import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main()
{
  runApp(const SudokuGameApp());
}

/// Root widget of the Sudoku application
class SudokuGameApp extends StatelessWidget
{
  const SudokuGameApp({super.key});

  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      title: 'Sudoku Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SudokuGamePage(title: 'Sudoku'),
    );
  }
}

/// Main game screen
class SudokuGamePage extends StatefulWidget
{
  const SudokuGamePage({super.key, required this.title});

  final String title;

  @override
  State<SudokuGamePage> createState() => _SudokuGamePageState();
}

class _SudokuGamePageState extends State<SudokuGamePage>
{

  // =========================
  // Game State
  // =========================

  /// Current player board
  final List<List<int>> board =
  List.generate(9, (_) => List.generate(9, (_) => 0));

  /// Solution board (from API)
  final List<List<int>> solution =
  List.generate(9, (_) => List.generate(9, (_) => 0));

  /// Marks original (locked) cells
  final List<List<bool>> givenCells =
  List.generate(9, (_) => List.generate(9, (_) => false));

  int selectedRow = -1;
  int selectedCol = -1;
  int selectedNumber = 0;

  // =========================
  // API
  // =========================

  /// Fetches a new Sudoku puzzle from the API
  Future<bool> fetchSudokuPuzzle() async
  {
    final url = Uri.parse('https://sudoku-api.vercel.app/api/dosuku');

    try
    {
      final response = await http.get(url);
      if (response.statusCode != 200) return false;

      final data = json.decode(response.body);
      final grid = data['newboard']['grids'][0];

      if (!mounted) return false;

      setState(()
      {
        for (int r = 0; r < 9; r++)
        {
          for (int c = 0; c < 9; c++)
          {
            board[r][c] = grid['value'][r][c];
            solution[r][c] = grid['solution'][r][c];
            givenCells[r][c] = board[r][c] != 0;
          }
        }
        selectedRow = -1;
        selectedCol = -1;
        selectedNumber = 0;
      });

      return true;
    } catch (_)
    {
      return false;
    }
  }

  // =========================
  // Sudoku Logic
  // =========================

  /// Checks if a number placement is valid
  bool isValid(int row, int col, int number)
  {
    for (int i = 0; i < 9; i++)
    {
      if (i != col && board[row][i] == number) return false;
      if (i != row && board[i][col] == number) return false;
    }

    int startRow = row - row % 3;
    int startCol = col - col % 3;

    for (int r = startRow; r < startRow + 3; r++)
    {
      for (int c = startCol; c < startCol + 3; c++)
      {
        if ((r != row || c != col) && board[r][c] == number) return false;
      }
    }
    return true;
  }

  /// Returns true if the cell conflicts with Sudoku rules
  bool hasConflict(int row, int col)
  {
    int number = board[row][col];
    if (number == 0) return false;
    return !isValid(row, col, number);
  }

  /// Clears the entire board
  void clearBoard()
  {
    setState(()
    {
      for (int r = 0; r < 9; r++)
      {
        for (int c = 0; c < 9; c++)
        {
          board[r][c] = 0;
          givenCells[r][c] = false;
        }
      }
      selectedRow = -1;
      selectedCol = -1;
      selectedNumber = 0;
    });
  }

  /// Inserts one correct value into an empty cell
  void giveHint() {
    for (int r = 0; r < 9; r++)
    {
      for (int c = 0; c < 9; c++)
      {
        if (board[r][c] == 0 && !givenCells[r][c])
        {
          setState(() {
            board[r][c] = solution[r][c];
            givenCells[r][c] = true;
          });

          if (checkVictory()) showVictoryDialog();
          return;
        }
      }
    }
  }

  // =========================
  // Victory Logic
  // =========================

  bool isBoardFull() =>
      board.every((row) => row.every((cell) => cell != 0));

  bool isBoardValid()
  {
    for (int r = 0; r < 9; r++)
    {
      for (int c = 0; c < 9; c++)
      {
        if (!isValid(r, c, board[r][c])) return false;
      }
    }
    return true;
  }

  bool checkVictory() => isBoardFull() && isBoardValid();

  void showVictoryDialog()
  {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 Congratulations!'),
        content: const Text('You solved the Sudoku correctly!'),
        actions: [
          TextButton(
            onPressed: ()
            {
              Navigator.pop(context);
              fetchSudokuPuzzle();
            },
            child: const Text('New Game'),
          )
        ],
      ),
    );
  }

  // =========================
  // UI
  // =========================

  Widget buildCell(int row, int col, double size)
  {
    BorderSide thick = const BorderSide(width: 2);
    BorderSide thin = const BorderSide(width: 0.5);

    Color background;
    if (row == selectedRow && col == selectedCol)
    {
      background = Colors.yellow.shade300;
    } else if (selectedNumber != 0 && board[row][col] == selectedNumber)
    {
      background = Colors.lightBlue.shade100;
    } else
    {
      background =
      ((row ~/ 3 + col ~/ 3) % 2 == 0) ? Colors.grey.shade200 : Colors.white;
    }

    return GestureDetector(
      onTap: ()
      {
        setState(()
        {
          selectedRow = row;
          selectedCol = col;
          selectedNumber = board[row][col];
        });
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          border: Border(
            top: row % 3 == 0 ? thick : thin,
            left: col % 3 == 0 ? thick : thin,
            right: (col + 1) % 3 == 0 ? thick : thin,
            bottom: (row + 1) % 3 == 0 ? thick : thin,
          ),
        ),
        child: Center(
          child: Text(
            board[row][col] == 0 ? '' : board[row][col].toString(),
            style: TextStyle(
              fontSize: 20,
              color: givenCells[row][col]
                  ? Colors.black
                  : hasConflict(row, col)
                  ? Colors.red
                  : Colors.blue,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildBoard(double cellSize)
  {
    return Column(
      children: List.generate(
        9,
            (r) => Row(
          children:
          List.generate(9, (c) => buildCell(r, c, cellSize)),
        ),
      ),
    );
  }

  // =========================
  // Lifecycle & Build
  // =========================

  @override
  void initState()
  {
    super.initState();
    fetchSudokuPuzzle();
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: (event)
        {
          if (event is RawKeyDownEvent)
          {
            handleKeyboardInput(event.logicalKey.keyLabel);
          }
        },
        child: LayoutBuilder(
          builder: (_, constraints)
          {
            final cellSize = constraints.maxWidth / 9;
            return Column(
              children: [
                const SizedBox(height: 16),
                buildBoard(cellSize),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(onPressed: clearBoard, child: const Text('Clear')),
                    ElevatedButton(onPressed: giveHint, child: const Text('Hint')),
                    ElevatedButton(
                        onPressed: fetchSudokuPuzzle,
                        child: const Text('New Puzzle')),
                  ],
                )
              ],
            );
          },
        ),
      ),
    );
  }

  // =========================
  // Keyboard Input
  // =========================

  void handleKeyboardInput(String value)
  {
    if (selectedRow == -1 || selectedCol == -1) return;
    if (givenCells[selectedRow][selectedCol]) return;

    setState(() {
      if (value == 'Backspace' || value == 'Delete')
      {
        board[selectedRow][selectedCol] = 0;
      } else
      {
        final num = int.tryParse(value);
        if (num != null && num >= 1 && num <= 9) {
          board[selectedRow][selectedCol] = num;
        }
      }
    });

    if (checkVictory()) showVictoryDialog();
  }
}

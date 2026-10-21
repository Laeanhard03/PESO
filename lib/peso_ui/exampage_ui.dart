import 'dart:async';

import 'package:flutter/material.dart';

class AIExamPage extends StatefulWidget {
  final String jobTitle;
  final String company;

  const AIExamPage({super.key, required this.jobTitle, required this.company});

  @override
  State<AIExamPage> createState() => _AIExamPageState();
}

class _AIExamPageState extends State<AIExamPage> {
  final Color pesoGreen = const Color(0xFF2E7D32);

  // State variables
  int _currentIndex = 0;
  final Map<int, dynamic> _selectedAnswers =
      {}; // Holds Strings (A/B/C/D) or Text (Essays)

  // Timer variables
  late Timer _timer;
  int _timeLeftInSeconds = 45 * 60; // 45 Minutes for mixed format exam

  // --- MOCK DATABASE: HYBRID AI EXAM (SKILLS + INTERVIEW) ---
  final List<Map<String, dynamic>> _mockExamData = [
    {
      "question_id": "q1",
      "format": "multiple_choice",
      "difficulty": "Intermediate",
      "skill_tested": "System Architecture",
      "type": "Technical",
      "question_text": "Which architectural pattern is most suited for maintaining highly scalable, decoupled Flutter applications?",
      "options": {
        "A": "MVC (Model-View-Controller)",
        "B": "BLoC / Clean Architecture",
        "C": "Standard StatefulWidget setState()",
        "D": "Singletons for all data management",
      },
    },
    {
      "question_id": "q2",
      "format": "visual_match",
      "difficulty": "Advanced",
      "skill_tested": "Database Logic & Spatial Reasoning",
      "type": "Cognitive/Technical",
      "question_text": "Analyze the visual schemas below. Which option correctly depicts a 'Many-to-Many' relationship resolved via a Junction Table?",
      "options": {
        "A": {"label": "Direct 1:1 Link", "icon": Icons.compare_arrows},
        "B": {"label": "One-to-Many Fork", "icon": Icons.account_tree_outlined},
        "C": {
          "label": "Junction/Associative Entity",
          "icon": Icons.hub_outlined,
        },
        "D": {"label": "Isolated Tables", "icon": Icons.grid_view},
      },
    },
    {
      "question_id": "q3",
      "format": "essay",
      "difficulty": "Advanced",
      "skill_tested": "Conflict Resolution & Communication",
      "type": "Behavioral Interview",
      "question_text": "Tell me about a time you strongly disagreed with a team member on a technical approach. How did you handle the situation, and what was the outcome?",
      "ai_prompt": "The AI will evaluate this response for empathy, logical reasoning, and professional communication.",
    },
    {
      "question_id": "q4",
      "format": "multiple_choice",
      "difficulty": "Intermediate",
      "skill_tested": "Probability & Statistics",
      "type": "Quantitative",
      "question_text": "An algorithm flags a transaction as fraudulent with 90% accuracy. If you test it with 200 known fraudulent transactions, how many is it statistically expected to miss (false negatives)?",
      "options": {"A": "10", "B": "20", "C": "90", "D": "180"},
    },
    {
      "question_id": "q5",
      "format": "essay",
      "difficulty": "Intermediate",
      "skill_tested": "Problem Solving / Situational",
      "type": "Technical Interview",
      "question_text": "You are tasked with building the localized portal for the Montalban PESO office. What are the first three technical steps you would take to ensure the system is secure and scalable?",
      "ai_prompt": "The AI will evaluate this response for technical planning, security awareness, and structural logic.",
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeftInSeconds > 0) {
        setState(() => _timeLeftInSeconds--);
      } else {
        _timer.cancel();
        _submitExam();
      }
    });
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _submitExam() {
    _timer.cancel();

    // MOCK GRADING LOGIC: Assumes 80% pass if they answered everything.
    // In production, the backend sends Prompt 2 containing the essay text and MCQ answers.
    int answeredCount = _selectedAnswers.length;
    double percentage = (answeredCount / _mockExamData.length) * 100;

    Navigator.pop(
      context,
      percentage >= 100 ? 85 : 40,
    ); // Returns 85 if complete, 40 if incomplete
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text('Quit Assessment?'),
            content: const Text(
              'If you leave now, your progress will be lost and this will trigger a failed AI Action Plan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Continue Exam',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop(true);
                  Navigator.of(context).pop(0);
                },
                child: const Text('Quit Exam'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- DYNAMIC AI CATEGORY STYLING ---
  Map<String, dynamic> _getCategoryStyle(String type) {
    if (type.contains('Technical Interview')) {
      return {'color': Colors.indigo, 'icon': Icons.record_voice_over};
    }
    if (type.contains('Behavioral')) {
      return {'color': Colors.pink, 'icon': Icons.people_alt_outlined};
    }
    if (type.contains('Cognitive')) {
      return {'color': Colors.purple, 'icon': Icons.extension_outlined};
    }
    if (type.contains('Quantitative')) {
      return {'color': Colors.orange, 'icon': Icons.calculate_outlined};
    }
    return {'color': Colors.blue, 'icon': Icons.code};
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;
    final medium = screenWidth < 1024;
    final currentQuestion = _mockExamData[_currentIndex];
    final double progress = (_currentIndex + 1) / _mockExamData.length;
    final categoryStyle = _getCategoryStyle(currentQuestion['type']);
    final Color catColor = categoryStyle['color'];
    final IconData catIcon = categoryStyle['icon'];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildDesignerAppBar(),
        body: Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(pesoGreen),
              minHeight: 6,
            ),

            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 900,
                  ), // Slightly wider for visual grids
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : (medium ? 24 : 40),
                      vertical: compact ? 16 : (medium ? 24 : 40),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges & Progress
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildBadge(
                              catIcon,
                              currentQuestion['type'],
                              catColor,
                            ),
                            _buildBadge(
                              Icons.radar,
                              'Evaluating: ${currentQuestion['skill_tested']}',
                              Colors.blueGrey,
                            ),
                            Text(
                              'Question ${_currentIndex + 1} of ${_mockExamData.length}',
                              style: TextStyle(
                                fontSize: compact ? 12 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 20 : 40),

                        // Question Text
                        Text(
                          currentQuestion['question_text'],
                          style: TextStyle(
                            fontSize: compact ? 20 : (medium ? 23 : 26),
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 40),

                        // Dynamic Content Renderer
                        Expanded(
                          child: _buildDynamicQuestionContent(
                            currentQuestion,
                            catColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Footer Navigation
            _buildFooterControls(),
          ],
        ),
      ),
    );
  }

  // --- DYNAMIC CONTENT RENDERER ---
  Widget _buildDynamicQuestionContent(
    Map<String, dynamic> questionData,
    Color activeColor,
  ) {
    String format = questionData['format'];

    switch (format) {
      case 'multiple_choice':
        return _buildMultipleChoice(questionData['options'], activeColor);
      case 'visual_match':
        return _buildVisualMatch(questionData['options'], activeColor);
      case 'essay':
        return _buildEssayEditor(questionData['ai_prompt'], activeColor);
      default:
        return const Center(child: Text('Unknown question format.'));
    }
  }

  // 1. STANDARD MULTIPLE CHOICE
  Widget _buildMultipleChoice(Map<String, dynamic> options, Color activeColor) {
    return ListView.builder(
      itemCount: options.keys.length,
      itemBuilder: (context, index) {
        String key = options.keys.elementAt(index);
        return _buildInteractiveOptionCard(key, options[key], activeColor);
      },
    );
  }

  // 2. VISUAL / SPATIAL MATCH (2x2 Grid)
  Widget _buildVisualMatch(Map<String, dynamic> options, Color activeColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? 1 : 2,
            crossAxisSpacing: compact ? 8 : 20,
            mainAxisSpacing: compact ? 8 : 20,
            childAspectRatio: compact ? 2.4 : 1.5,
          ),
          itemCount: options.keys.length,
          itemBuilder: (context, index) {
            final key = options.keys.elementAt(index);
            final Map<String, dynamic> data = options[key];
            final isSelected = _selectedAnswers[_currentIndex] == key;

            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedAnswers[_currentIndex] = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? activeColor : Colors.grey.shade200,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                          ),
                        ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 8 : 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              data['icon'],
                              size: compact ? 38 : 70,
                              color: isSelected
                                  ? activeColor
                                  : Colors.grey.shade400,
                            ),
                            SizedBox(width: compact ? 10 : 18),
                            Flexible(
                              child: Text(
                                data['label'],
                                textAlign: compact
                                    ? TextAlign.start
                                    : TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: compact ? 14 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: compact ? 6 : 15,
                        right: compact ? 6 : 15,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: activeColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 3. AI EVALUATED ESSAY (Interview Mode)
  Widget _buildEssayEditor(String aiPrompt, Color activeColor) {
    String currentText = _selectedAnswers[_currentIndex] ?? '';
    int wordCount = currentText.isEmpty
        ? 0
        : currentText.trim().split(RegExp(r'\s+')).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.smart_toy, color: activeColor),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  aiPrompt,
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: TextField(
              maxLines: null, // Expands infinitely
              expands: true,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontSize: 18,
                height: 1.6,
                color: Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Type your response here. Treat this as if you are speaking to an interviewer...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.all(30),
                border: InputBorder.none,
              ),
              onChanged: (val) =>
                  setState(() => _selectedAnswers[_currentIndex] = val),
              controller: TextEditingController(text: currentText)
                ..selection = TextSelection.collapsed(
                  offset: currentText.length,
                ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Word Count: $wordCount',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: wordCount > 20 ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 10),
            if (wordCount < 20)
              const Text(
                '(Minimum 20 words recommended)',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
          ],
        ),
      ],
    );
  }

  // --- DESIGNER UI HELPERS ---

  AppBar _buildDesignerAppBar() {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final titleBlock = Row(
      children: [
        IconButton(
          tooltip: 'Close assessment',
          visualDensity: compact
              ? VisualDensity.compact
              : VisualDensity.standard,
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: () => _onWillPop(),
        ),
        SizedBox(width: compact ? 4 : 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Live AI Assessment Engine',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: compact ? 10 : 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.jobTitle} @ ${widget.company}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: compact ? 13 : 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final timerBadge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 20,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        color: _timeLeftInSeconds < 300
            ? Colors.red.shade50
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _timeLeftInSeconds < 300
              ? Colors.red.shade200
              : Colors.blue.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: _timeLeftInSeconds < 300 ? Colors.red : Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(_timeLeftInSeconds),
            style: TextStyle(
              color: _timeLeftInSeconds < 300
                  ? Colors.red
                  : Colors.blue.shade700,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 14 : 16,
            ),
          ),
        ],
      ),
    );

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: compact ? 112 : 90,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 0 : 20,
          vertical: compact ? 4 : 0,
        ),
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 44, child: titleBlock),
                  Align(alignment: Alignment.centerRight, child: timerBadge),
                ],
              )
            : Row(
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 16),
                  timerBadge,
                ],
              ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.shade200, height: 1),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? screenWidth - 32 : 380),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveOptionCard(
    String key,
    String text,
    Color activeThemeColor,
  ) {
    bool isSelected = _selectedAnswers[_currentIndex] == key;

    return GestureDetector(
      onTap: () => setState(() => _selectedAnswers[_currentIndex] = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: isSelected
              ? activeThemeColor.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? activeThemeColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeThemeColor.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: isSelected ? activeThemeColor : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? activeThemeColor : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        key,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.black87 : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterControls() {
    bool hasAnsweredCurrent;
    if (_mockExamData[_currentIndex]['format'] == 'essay') {
      final text = _selectedAnswers[_currentIndex] ?? '';
      hasAnsweredCurrent = text.trim().isNotEmpty;
    } else {
      hasAnsweredCurrent = _selectedAnswers.containsKey(_currentIndex);
    }

    final isLastQuestion = _currentIndex == _mockExamData.length - 1;
    final compact = MediaQuery.sizeOf(context).width < 900;

    final previousButton = OutlinedButton.icon(
      onPressed: () => setState(() => _currentIndex--),
      icon: const Icon(Icons.arrow_back),
      label: const Text('Previous'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 25,
          vertical: compact ? 14 : 20,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );

    final primaryButton = isLastQuestion
        ? ElevatedButton.icon(
            onPressed: hasAnsweredCurrent ? _submitExam : null,
            icon: const Icon(Icons.send),
            label: const Text(
              'Submit Assessment & Send to AI',
              textAlign: TextAlign.center,
              softWrap: true,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: pesoGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 35,
                vertical: compact ? 14 : 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
          )
        : ElevatedButton(
            onPressed: hasAnsweredCurrent
                ? () => setState(() => _currentIndex++)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 35,
                vertical: compact ? 14 : 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next Question',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 40,
        vertical: compact ? 12 : 25,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentIndex > 0) ...[
                      previousButton,
                      const SizedBox(height: 8),
                    ],
                    primaryButton,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _currentIndex > 0
                        ? previousButton
                        : const SizedBox(width: 120),
                    primaryButton,
                  ],
                ),
        ),
      ),
    );
  }
}

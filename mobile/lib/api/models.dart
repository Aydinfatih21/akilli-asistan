// Sunucu JSON'larının Dart karşılıkları (bkz. docs/API.md).

int? asInt(Object? v) => v is num ? v.toInt() : (v == null ? null : int.tryParse(v.toString()));

String asStr(Object? v, [String fallback = '']) => v == null ? fallback : v.toString();

DateTime? asDate(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

Map<String, dynamic> asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<T> asList<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    v is List ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList() : <T>[];

List<String> asStrList(Object? v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

// ------------------------------------------------------------------ kimlik
class User {
  const User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> j) =>
      User(id: asStr(j['id']), name: asStr(j['name']), email: asStr(j['email']));

  final String id;
  final String name;
  final String email;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

class AuthResult {
  const AuthResult(this.token, this.user);

  factory AuthResult.fromJson(Map<String, dynamic> j) =>
      AuthResult(asStr(j['token']), User.fromJson(asMap(j['user'])));

  final String token;
  final User user;
}

// ------------------------------------------------------------------ dersler
class Course {
  const Course({
    required this.id,
    required this.name,
    this.noteCount = 0,
    this.attemptCount = 0,
    this.avgPercent,
    this.lastActivity,
  });

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: asStr(j['id']),
        name: asStr(j['name']),
        noteCount: asInt(j['note_count']) ?? 0,
        attemptCount: asInt(j['attempt_count']) ?? 0,
        avgPercent: asInt(j['avg_percent']),
        lastActivity: asDate(j['last_activity'] ?? j['created_at']),
      );

  final String id;
  final String name;
  final int noteCount;
  final int attemptCount;
  final int? avgPercent; // hiç test çözülmediyse null
  final DateTime? lastActivity;
}

// ------------------------------------------------------------------ sohbet
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    this.courseId,
    this.courseName,
    this.messageCount = 0,
    this.lastMessage,
    this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: asStr(j['id']),
        title: asStr(j['title'], 'Sohbet'),
        courseId: j['course_id']?.toString(),
        courseName: j['course_name']?.toString(),
        messageCount: asInt(j['message_count']) ?? 0,
        lastMessage: j['last_message']?.toString(),
        updatedAt: asDate(j['updated_at']),
      );

  final String id;
  final String title;
  final String? courseId;
  final String? courseName;
  final int messageCount;
  final String? lastMessage;
  final DateTime? updatedAt;
}

class ChatMessage {
  const ChatMessage({required this.id, required this.role, required this.content, this.model, this.createdAt});

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: asStr(j['id']),
        role: asStr(j['role'], 'assistant'),
        content: asStr(j['content']),
        model: j['model']?.toString(),
        createdAt: asDate(j['created_at']),
      );

  final String id;
  final String role; // user | assistant
  final String content;
  final String? model;
  final DateTime? createdAt;

  bool get isUser => role == 'user';
}

class ChatReply {
  const ChatReply(this.conversationId, this.reply);

  factory ChatReply.fromJson(Map<String, dynamic> j) =>
      ChatReply(asStr(j['conversation_id']), ChatMessage.fromJson(asMap(j['reply'])));

  final String conversationId;
  final ChatMessage reply;
}

// ------------------------------------------------------------------ notlar
class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    this.preview = '',
    this.hasSummary = false,
    this.source = 'text',
    this.createdAt,
  });

  factory NoteItem.fromJson(Map<String, dynamic> j) => NoteItem(
        id: asStr(j['id']),
        title: asStr(j['title']),
        preview: asStr(j['preview']),
        hasSummary: j['has_summary'] == true,
        source: asStr(j['source'], 'text'),
        createdAt: asDate(j['created_at']),
      );

  final String id;
  final String title;
  final String preview;
  final bool hasSummary;
  final String source;
  final DateTime? createdAt;
}

class NoteSummary {
  const NoteSummary({required this.short, required this.keyPoints, required this.keywords});

  factory NoteSummary.fromJson(Map<String, dynamic> j) => NoteSummary(
        short: asStr(j['short']),
        keyPoints: asStrList(j['key_points']),
        keywords: asStrList(j['keywords']),
      );

  final String short;
  final List<String> keyPoints;
  final List<String> keywords;
}

class SummaryResult {
  const SummaryResult({required this.noteId, required this.summary, this.model, this.cached = false});

  factory SummaryResult.fromJson(Map<String, dynamic> j) => SummaryResult(
        noteId: asStr(j['note_id']),
        summary: NoteSummary.fromJson(asMap(j['summary'])),
        model: j['model']?.toString(),
        cached: j['cached'] == true,
      );

  final String noteId;
  final NoteSummary summary;
  final String? model;
  final bool cached;
}

// ------------------------------------------------------------------ testler
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.position,
    required this.question,
    required this.options,
    required this.topic,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: asStr(j['id']),
        position: asInt(j['position']) ?? 0,
        question: asStr(j['question']),
        options: asStrList(j['options']),
        topic: asStr(j['topic']),
      );

  final String id;
  final int position;
  final String question;
  final List<String> options;
  final String topic;
}

class Quiz {
  const Quiz({required this.id, required this.title, required this.questions, this.model, this.difficulty});

  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
        id: asStr(j['quiz_id']),
        title: asStr(j['title'], 'Test'),
        model: j['model']?.toString(),
        difficulty: j['difficulty']?.toString(),
        questions: asList(j['questions'], QuizQuestion.fromJson)..sort((a, b) => a.position.compareTo(b.position)),
      );

  final String id;
  final String title;
  final String? model;
  final String? difficulty;
  final List<QuizQuestion> questions;
}

class QuestionResult {
  const QuestionResult({
    required this.questionId,
    required this.selectedIndex,
    required this.correctIndex,
    required this.isCorrect,
    required this.explanation,
  });

  factory QuestionResult.fromJson(Map<String, dynamic> j) => QuestionResult(
        questionId: asStr(j['question_id']),
        selectedIndex: asInt(j['selected_index']),
        correctIndex: asInt(j['correct_index']) ?? 0,
        isCorrect: j['is_correct'] == true,
        explanation: asStr(j['explanation']),
      );

  final String questionId;
  final int? selectedIndex; // null: boş bırakıldı
  final int correctIndex;
  final bool isCorrect;
  final String explanation;
}

class QuizResult {
  const QuizResult({
    required this.attemptId,
    required this.score,
    required this.total,
    required this.percent,
    required this.results,
    required this.weakTopics,
    required this.recommendation,
    required this.recommendationSource,
  });

  factory QuizResult.fromJson(Map<String, dynamic> j) => QuizResult(
        attemptId: asStr(j['attempt_id']),
        score: asInt(j['score']) ?? 0,
        total: asInt(j['total']) ?? 0,
        percent: asInt(j['percent']) ?? 0,
        results: asList(j['results'], QuestionResult.fromJson),
        weakTopics: asStrList(j['weak_topics']),
        recommendation: asStr(j['recommendation']),
        recommendationSource: asStr(j['recommendation_source'], 'ai'),
      );

  final String attemptId;
  final int score;
  final int total;
  final int percent;
  final List<QuestionResult> results;
  final List<String> weakTopics;
  final String recommendation;
  final String recommendationSource; // ai | fallback
}

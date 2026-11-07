import 'api_client.dart';
import 'models.dart';

/// docs/API.md'deki uç noktaların tipli karşılıkları.
class AsistanApi {
  AsistanApi(this.client);

  final ApiClient client;

  // ---------------------------------------------------------------- kimlik
  Future<AuthResult> login(String email, String password) async =>
      AuthResult.fromJson(await client.post('auth/login', body: {'email': email, 'password': password}));

  Future<AuthResult> register(String name, String email, String password) async => AuthResult.fromJson(
      await client.post('auth/register', body: {'name': name, 'email': email, 'password': password}));

  Future<void> logout() async {
    await client.post('auth/logout');
  }

  // ---------------------------------------------------------------- dersler
  Future<List<Course>> courses() async => asList((await client.post('courses/list'))['courses'], Course.fromJson);

  Future<Course> createCourse(String name) async =>
      Course.fromJson(asMap((await client.post('courses/create', body: {'name': name}))['course']));

  // ---------------------------------------------------------------- sohbet
  Future<ChatReply> sendMessage(String message, {String? conversationId, String? courseId, String? model}) async =>
      ChatReply.fromJson(await client.post(
        'chat/send',
        body: {'message': message, 'conversation_id': conversationId, 'course_id': courseId, 'model': model},
        timeout: ApiClient.aiTimeout,
      ));

  Future<List<Conversation>> conversations({String? courseId}) async => asList(
      (await client.post('chat/conversations', body: {'course_id': courseId}))['conversations'],
      Conversation.fromJson);

  Future<List<ChatMessage>> history(String conversationId) async => asList(
      (await client.post('chat/history', body: {'conversation_id': conversationId}))['messages'],
      ChatMessage.fromJson);

  // ---------------------------------------------------------------- notlar
  Future<String> createNote({
    required String courseId,
    required String title,
    required String content,
    String source = 'text',
  }) async {
    final data = await client.post('notes/create',
        body: {'course_id': courseId, 'title': title, 'content': content, 'source': source});
    return asStr(asMap(data['note'])['id']);
  }

  Future<List<NoteItem>> notes(String courseId) async =>
      asList((await client.post('notes/list', body: {'course_id': courseId}))['notes'], NoteItem.fromJson);

  Future<SummaryResult> summarize(String noteId, {bool force = false, String? model}) async =>
      SummaryResult.fromJson(await client.post(
        'notes/summarize',
        body: {'note_id': noteId, 'force': force, 'model': model},
        timeout: ApiClient.aiTimeout,
      ));

  // ---------------------------------------------------------------- testler
  Future<Quiz> generateQuiz(String noteId, {int count = 5, String difficulty = 'medium', String? model}) async =>
      Quiz.fromJson(await client.post(
        'quizzes/generate',
        body: {'note_id': noteId, 'question_count': count, 'difficulty': difficulty, 'model': model},
        timeout: ApiClient.aiTimeout,
      ));

  /// [answers]: soru id → seçilen şık (0-3) veya boş bırakıldıysa null.
  Future<QuizResult> submitQuiz(String quizId, Map<String, int?> answers, {String? model}) async =>
      QuizResult.fromJson(await client.post(
        'quizzes/submit',
        body: {
          'quiz_id': quizId,
          'answers': [
            for (final e in answers.entries) {'question_id': e.key, 'selected_index': e.value},
          ],
          'model': model,
        },
        timeout: ApiClient.aiTimeout,
      ));
}

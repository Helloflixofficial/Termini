class ApiConstants {
  const ApiConstants._();

  // Auth & Profile Endpoints
  static const String authSignIn = '/api/auth/sign-in';
  static const String authSignUp = '/api/auth/sign-up';
  static const String userProfile = '/api/user/profile';

  // Student Endpoints
  static const String dashboard = '/api/dashboard';
  static const String categories = '/api/categories';
  static const String courses = '/api/courses';
  static String course(String id) => '/api/courses/$id';
  static String chapter(String courseId, String chapterId) =>
      '/api/courses/$courseId/chapters/$chapterId';
  static String chapterProgress(String courseId, String chapterId) =>
      '/api/courses/$courseId/chapters/$chapterId/progress';
  static String checkout(String courseId) =>
      '/api/courses/$courseId/checkout';

  // LiveKit Meetings
  static const String liveKitSessions = '/api/livekit/sessions';
  static String liveKitSession(String id) => '/api/livekit/sessions/$id';
  static const String liveKitToken = '/api/livekit/token';
  static const String liveKitAdmin = '/api/livekit/admin';

  // Teacher Endpoints
  static const String teacherCourses = '/api/teacher/courses';
  static const String teacherAnalytics = '/api/teacher/analytics';
  static String coursePublish(String id) => '/api/courses/$id/publish';
  static String courseUnpublish(String id) => '/api/courses/$id/unpublish';
  static String courseAttachments(String courseId) =>
      '/api/courses/$courseId/attachments';
  static String courseAttachment(String courseId, String attachmentId) =>
      '/api/courses/$courseId/attachments/$attachmentId';
  static String courseChapters(String courseId) =>
      '/api/courses/$courseId/chapters';
  static String chaptersReorder(String courseId) =>
      '/api/courses/$courseId/chapters/reorder';
  static String chapterPublish(String courseId, String chapterId) =>
      '/api/courses/$courseId/chapters/$chapterId/publish';
  static String chapterUnpublish(String courseId, String chapterId) =>
      '/api/courses/$courseId/chapters/$chapterId/unpublish';

  // Community Endpoints
  static const String communitySpaces = '/api/community/spaces';
  static String communitySpace(String id) => '/api/community/spaces/$id';
  static const String communityPosts = '/api/community/posts';
  static String communityPost(String id) => '/api/community/posts/$id';
  static String communityComments(String postId) =>
      '/api/community/posts/$postId/comments';
  static const String communitySettings = '/api/community/settings';
}

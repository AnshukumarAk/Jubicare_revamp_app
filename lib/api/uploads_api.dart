import 'api_client.dart';

/// POST /api/mobile/uploads — prescription / report photos.
///
/// The register form calls [uploadImage] the moment the counsellor captures
/// a photo. The server stores the file under uploads/patient_docs/ with a
/// random name and returns that name; the sync payload then carries the
/// server name instead of the phone-local path, so the doctor / dashboard
/// can fetch the image from any device via GET /uploads/<file_name>.
class UploadsApi {
  final ApiClient client;
  UploadsApi(this.client);

  /// Upload one image. Returns `{file_name, url, size}` where `file_name`
  /// is e.g. "patient_docs/3f2a….jpg" — the value to persist in
  /// appointment_attachment.file_path.
  Future<Map<String, dynamic>> uploadImage(String filePath) async {
    final res = await client.postMultipartFile('/mobile/uploads',
        filePath: filePath);
    return (res as Map).cast<String, dynamic>();
  }
}

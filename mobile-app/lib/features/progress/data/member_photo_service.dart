import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';

class SelectedProgressImage {
  const SelectedProgressImage({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });
  final String name;
  final String mimeType;
  final Uint8List bytes;
}

String? validateProgressImage(SelectedProgressImage image) {
  if (image.bytes.isEmpty || image.bytes.length > 5 * 1024 * 1024) {
    return 'Ảnh phải nhỏ hơn hoặc bằng 5 MB.';
  }
  final name = image.name.toLowerCase();
  final bytes = image.bytes;
  final png =
      image.mimeType == 'image/png' &&
      name.endsWith('.png') &&
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10;
  final jpeg =
      image.mimeType == 'image/jpeg' &&
      (name.endsWith('.jpg') || name.endsWith('.jpeg')) &&
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  return png || jpeg ? null : 'Chỉ chọn ảnh PNG hoặc JPEG hợp lệ.';
}

abstract interface class ProgressPhotoPicker {
  Future<SelectedProgressImage?> pick();
}

class DeviceProgressPhotoPicker implements ProgressPhotoPicker {
  DeviceProgressPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<SelectedProgressImage?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('Ảnh phải nhỏ hơn hoặc bằng 5 MB.');
    }
    final name = file.name;
    final mime =
        file.mimeType ??
        (name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    return SelectedProgressImage(
      name: name,
      mimeType: mime,
      bytes: await file.readAsBytes(),
    );
  }
}

abstract interface class MemberPhotoService {
  Future<List<ProgressPhoto>> getPage(int page);
  Future<String> upload(SelectedProgressImage image);
  Future<ProgressPhoto> create(Map<String, Object?> payload);
  Future<Uri> getAccessUrl(String mediaId);
}

class MemberPhotoApi implements MemberPhotoService {
  const MemberPhotoApi(this.client);
  final ApiClient client;

  @override
  Future<List<ProgressPhoto>> getPage(int page) async =>
      (await client.get<List<ProgressPhoto>>(
        '/progress-photos',
        queryParameters: {'page': page, 'pageSize': 20},
        decode: (value) => (value as List).map(ProgressPhoto.fromJson).toList(),
      )).data;

  @override
  Future<String> upload(SelectedProgressImage image) async {
    final validation = validateProgressImage(image);
    if (validation != null) throw FormatException(validation);
    final response = await client.post<Map<String, dynamic>>(
      '/media/images',
      body: image.bytes,
      headers: {
        'content-type': image.mimeType,
        'x-image-purpose': 'PROGRESS_PHOTO',
        'x-file-name': image.name,
      },
      decode: (value) => Map<String, dynamic>.from(value as Map),
    );
    return response.data['id'] as String;
  }

  @override
  Future<ProgressPhoto> create(Map<String, Object?> payload) async =>
      (await client.post<ProgressPhoto>(
        '/progress-photos',
        body: payload,
        decode: ProgressPhoto.fromJson,
      )).data;

  @override
  Future<Uri> getAccessUrl(String mediaId) async {
    final response = await client.get<Map<String, dynamic>>(
      '/media/images/${Uri.encodeComponent(mediaId)}/access-url',
      decode: (value) => Map<String, dynamic>.from(value as Map),
    );
    final path = response.data['url'] as String;
    if (!path.startsWith('/api/v1/media/images/')) {
      throw const ApiException(
        kind: ApiExceptionKind.invalidResponse,
        message: 'URL ảnh không hợp lệ.',
      );
    }
    return client.resolveServerPath(path);
  }
}

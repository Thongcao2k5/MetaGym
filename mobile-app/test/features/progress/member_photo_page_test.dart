import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/presentation/member_photo_page.dart';

void main() {
  test('validates PNG/JPEG signatures and the five MB limit', () {
    final png = SelectedProgressImage(
      name: 'a.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    expect(validateProgressImage(png), isNull);
    expect(
      validateProgressImage(
        SelectedProgressImage(
          name: 'a.gif',
          mimeType: 'image/gif',
          bytes: png.bytes,
        ),
      ),
      isNotNull,
    );
    expect(
      validateProgressImage(
        SelectedProgressImage(
          name: 'a.png',
          mimeType: 'image/png',
          bytes: Uint8List(5 * 1024 * 1024 + 1),
        ),
      ),
      isNotNull,
    );
  });

  testWidgets('picks, uploads and records a progress photo', (tester) async {
    final service = _PhotoFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: MemberPhotoPage(service: service, picker: _PickerFixture()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có ảnh tiến trình.'), findsOneWidget);
    await tester.tap(find.text('Thêm ảnh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn ảnh'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('photo-date')),
      '23/10/2026 08:00',
    );
    await tester.tap(find.text('Lưu ảnh'));
    await tester.pumpAndSettle();
    expect(service.uploads, 1);
    expect(service.created?['mediaId'], 'media-1');
    expect(find.text('Ảnh tiến trình'), findsWidgets);
  });

  testWidgets(
    'shows upload failure and allows retry without duplicate selection',
    (tester) async {
      final service = _PhotoFixture(failFirst: true);
      await tester.pumpWidget(
        MaterialApp(
          home: MemberPhotoPage(service: service, picker: _PickerFixture()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm ảnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('photo-date')),
        '23/10/2026 08:00',
      );
      await tester.tap(find.text('Lưu ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Không tải được ảnh lên.'), findsOneWidget);
      await tester.tap(find.text('Lưu ảnh'));
      await tester.pumpAndSettle();
      expect(service.uploads, 2);
      expect(service.created?['mediaId'], 'media-1');
    },
  );
}

class _PickerFixture implements ProgressPhotoPicker {
  @override
  Future<SelectedProgressImage?> pick() async => SelectedProgressImage(
    name: 'progress.png',
    mimeType: 'image/png',
    bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
  );
}

class _PhotoFixture implements MemberPhotoService {
  _PhotoFixture({this.failFirst = false});
  final bool failFirst;
  int uploads = 0;
  Map<String, Object?>? created;
  @override
  Future<List<ProgressPhoto>> getPage(int page) async => [
    if (created != null)
      ProgressPhoto(
        id: 'photo-1',
        mediaId: 'media-1',
        takenAt: created!['takenAt'] as String,
        pose: created!['pose'] as String?,
      ),
  ];
  @override
  Future<String> upload(SelectedProgressImage image) async {
    uploads++;
    if (failFirst && uploads == 1) throw StateError('failed');
    return 'media-1';
  }

  @override
  Future<ProgressPhoto> create(Map<String, Object?> payload) async {
    created = payload;
    return (await getPage(1)).single;
  }

  @override
  Future<Uri> getAccessUrl(String mediaId) async =>
      Uri.parse('https://example.test/image.png');
}

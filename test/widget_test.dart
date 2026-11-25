import 'package:flutter_test/flutter_test.dart';
import 'package:item_rdc_admin/util/media_utils.dart';

void main() {
  group('MediaUtils', () {
    test('Google Drive : lien /view -> /preview', () {
      const url = 'https://drive.google.com/file/d/ABC123/view?usp=sharing';
      expect(MediaUtils.driveId(url), 'ABC123');
      expect(
        MediaUtils.documentViewUrl(url),
        'https://drive.google.com/file/d/ABC123/preview',
      );
    });

    test('PDF direct -> visionneuse en ligne', () {
      expect(
        MediaUtils.documentViewUrl('https://site.com/doc.pdf'),
        startsWith('https://docs.google.com/gview?embedded=1&url='),
      );
    });

    test('YouTube et fichiers vidéo', () {
      expect(MediaUtils.isYoutube('https://youtu.be/abc'), true);
      expect(MediaUtils.looksLikeVideoFile('https://site.com/v.mp4'), true);
      expect(MediaUtils.looksLikePdf('https://site.com/a.pdf'), true);
    });
  });
}

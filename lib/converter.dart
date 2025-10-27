import 'package:flutter/foundation.dart' show debugPrint;
import 'package:xml/xml.dart' as xml;

xml.XmlDocument convert(Map<String, dynamic> npSubscriptionData) {
  final List<dynamic> subscriptions = npSubscriptionData['subscriptions'] ?? [];
  final builder = xml.XmlBuilder();

  builder.processing('xml', 'version="1.0" encoding="UTF-8"');

  builder.element('opml', attributes: {'version': '2.0'}, nest: () {
    builder.element('head', nest: () {
      builder.element('title', nest: 'NewPipe Subscriptions');
    });

    builder.element('body', nest: () {
      for (var sub in subscriptions) {
        if (sub is Map<String, dynamic>) {
          final String name = sub['name'] ?? 'No Name';
          final String htmlUrl = sub['url'] ?? '';
          final int serviceId = sub['service_id'] ?? -1;

          if (serviceId == 0 && htmlUrl.contains('/channel/')) {
            try {
              String channelId = htmlUrl.split('/channel/').last;
              channelId = channelId.split('?').first.split('#').first;

              if (channelId.isNotEmpty) {
                final String xmlUrl =
                    'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId';

                builder.element('outline', attributes: {
                  'type': 'rss',
                  'text': name,
                  'xmlUrl': xmlUrl,
                  'htmlUrl': htmlUrl,
                });
              }
            } catch (e) {
              // In a Flutter app, this prints to the debug console.
              // For a production app, you might want to log this to the UI.
              debugPrint('Warning: Skipping malformed URL: $htmlUrl');
            }
          }
        }
      }
    });
  });

  return builder.buildDocument();
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:nhnk/storage.dart';
import 'package:path_provider/path_provider.dart' as path;

typedef Callback = void Function(bool);
typedef IcsCallback = void Function(Stream<List<int>>);

class LocalFileActions{

  static Future<String> _getTempDirectory()async{
    return (await path.getTemporaryDirectory()).path;
  }

  static Future<String?> _getDownloadsFolder()async{
    return (await path.getDownloadsDirectory())?.path;
  }

  static Future<String?> openFilePicker(String dialogTitle)async{
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      initialDirectory: await _getDownloadsFolder(),
      type: FileType.custom,
      allowedExtensions: ['ics', 'ICS'],
      allowMultiple: false,
    );
    return result?.xFiles[0].path;
  }

  static Future<String> cloneFileToTemp(String path, String filename)async{
    final file = File(path);
    final fileBytes = await file.readAsBytes();
    final clone = File((await _getTempDirectory()) + '/' + filename);
    if(await clone.exists()){
      await clone.delete(recursive: false);
    }
    await clone.create(recursive: true);
    await clone.writeAsBytes(fileBytes, flush: true);
    return clone.path;
  }

  static Future<Stream<List<int>>?> openFileReadStream(String path)async{
    final file = File(path);
    if(!await file.exists()){
      return null;
    }
    final stream = file.openRead();
    return stream;
  }
}

class IcsImportHelper{
  static const String ICSFILENAME = 'OfflineUserCalendar.ics';
  static void onCalendarUploadAction(Callback onResult){
    try{
      Future.delayed(Duration.zero, ()async{
        final path = await LocalFileActions.openFilePicker('');
        if(path == null || path.isEmpty){
          onResult(false);
          return;
        }
        final clonePath = await LocalFileActions.cloneFileToTemp(path, IcsImportHelper.ICSFILENAME);
        await DataCache.setICSFileLocation(clonePath);
        await DataCache.setHasICSFile(true);
        onResult(true);
      });
    }
    catch (_){
      onResult(false);
    }
  }

  static Future<bool> streamIcsFileContent(IcsCallback fileStream)async{
    final result = await LocalFileActions.openFileReadStream(DataCache.getICSFileLocation() ?? '');
    if(result == null){
      return false;
    }
    fileStream(result);
    return true;
  }
}

/// Writes the timetable out as an .ics the OS can hand to whatever calendar the
/// user already has. Deliberately avoids a device-calendar plugin: that would need
/// READ_CALENDAR/WRITE_CALENDAR, and this app should not hold those.
class IcsExportHelper{
  static const String EXPORTFILENAME = 'NHNK-orarend.ics';

  static String _fold(String line){
    // RFC 5545 caps content lines at 75 octets; longer ones continue with a leading space.
    if(line.length <= 73) return line;
    final buffer = StringBuffer();
    var rest = line;
    buffer.write(rest.substring(0, 73));
    rest = rest.substring(73);
    while(rest.isNotEmpty){
      final take = rest.length > 72 ? 72 : rest.length;
      buffer.write('\r\n ');
      buffer.write(rest.substring(0, take));
      rest = rest.substring(take);
    }
    return buffer.toString();
  }

  static String _escape(String value){
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  static String _utc(DateTime time){
    final t = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}T${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  }

  /// [entries] items must expose startEpoch, endEpoch, title, location and teacher.
  static String buildIcs(List<dynamic> entries){
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//NHNK//Nem Hivatalos Neptun Kliens//HU',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:NHNK',
    ];

    final stamp = _utc(DateTime.now());
    for(var i = 0; i < entries.length; i++){
      final e = entries[i];
      final start = DateTime.fromMillisecondsSinceEpoch(e.startEpoch as int);
      final end = DateTime.fromMillisecondsSinceEpoch(e.endEpoch as int);
      final title = _escape((e.title ?? '').toString());
      final location = _escape((e.location ?? '').toString());
      final teacher = _escape((e.teacher ?? '').toString());

      lines.addAll([
        'BEGIN:VEVENT',
        _fold('UID:nhnk-${e.startEpoch}-$i@nhnk.bali0531.hu'),
        'DTSTAMP:$stamp',
        'DTSTART:${_utc(start)}',
        'DTEND:${_utc(end)}',
        _fold('SUMMARY:$title'),
        if(location.isNotEmpty) _fold('LOCATION:$location'),
        if(teacher.isNotEmpty && teacher != '-') _fold('DESCRIPTION:$teacher'),
        'END:VEVENT',
      ]);
    }

    lines.add('END:VCALENDAR');
    return '${lines.join('\r\n')}\r\n';
  }

  /// Returns the written file path, or null when there is nothing to export.
  static Future<String?> writeExport(List<dynamic> entries) async{
    if(entries.isEmpty){
      return null;
    }
    final dir = (await path.getTemporaryDirectory()).path;
    final file = File('$dir/$EXPORTFILENAME');
    if(await file.exists()){
      await file.delete(recursive: false);
    }
    await file.create(recursive: true);
    await file.writeAsString(buildIcs(entries), flush: true);
    return file.path;
  }
}
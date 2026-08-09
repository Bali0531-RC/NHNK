import 'package:nhnk/platform_support.dart';
import 'dart:async';
import 'dart:convert' as conv;
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nhnk/API/ics_calendar.dart';
import 'package:nhnk/API/totp.dart';
import 'package:nhnk/Misc/clickable_text_span.dart';
import 'package:nhnk/colors.dart';
import 'package:nhnk/language.dart';
import '../storage.dart' as storage;
import 'dart:developer' as debug;
import '../storage.dart';
  
  class URLs{
    static const String INSTITUTIONS_URL = "https://mobilecloudservice.cloudapp.net/MobileServiceLib/MobileCloudService.svc/GetAllNeptunMobileUrls";
    static const String TRAININGS_URL = "/api/GetTrainings";
    static const String CALENDAR_URL = "/api/GetCalendarData";
    static const String PERIODTERMS_URL = "/api/GetPeriodTerms";
    static const String PERIODS_URL = "/api/GetPeriods";
    static const String GETCASHIN_URL = "/api/GetCashinData";
    static const String CURRICULUMS_URL = "/api/GetCurriculums";
    static const String MARKBOOK_URL = "/api/GetMarkbookData";
    static const String MESSAGES_URL = "/api/GetMessages";
    static const String MESSAGE_SET_READ = "/api/SetReadedMessage";
  }

  /// Some institutes run several interchangeable Neptun nodes -- Pannon answers on
  /// neptun-ws01 and neptun-ws03, and a dead node tends to hang rather than refuse,
  /// so a stalled request is the signal to move to another host.
  class InstituteFailover{
    static bool _switching = false;

    static String? originOf(String? url){
      if(url == null || url.isEmpty) return null;
      final parsed = Uri.tryParse(url);
      if(parsed == null || !parsed.hasAuthority) return null;
      return '${parsed.scheme}://${parsed.authority}';
    }

    /// Keeps whatever path the stored URL picked up during login -- the old API appends
    /// /MobileService.svc -- and only moves it onto a different host.
    static String? swapOrigin(String url, String newOrigin){
      final parsed = Uri.tryParse(url);
      if(parsed == null || !parsed.hasAuthority) return null;
      final idx = url.indexOf(parsed.authority);
      if(idx < 0) return null;
      return '$newOrigin${url.substring(idx + parsed.authority.length)}';
    }

    /// Points a request that was built against the old host at the current one.
    static Uri? rebuild(Uri original){
      final origin = originOf(storage.DataCache.getInstituteUrl());
      if(origin == null) return null;
      final swapped = swapOrigin(original.toString(), origin);
      return swapped == null ? null : Uri.tryParse(swapped);
    }

    static Future<bool> _isAlive(String baseUrl) async{
      try{
        // Short on purpose: the whole point is not to sit through another stalled connect.
        final resp = await http.get(Uri.parse('$baseUrl/api/Account/Authenticate'))
            .timeout(const Duration(seconds: 6));
        // A live node rejects the GET with JSON; a web front-end on the same name
        // answers with a page, and logging into that would never work.
        final body = resp.body.trimLeft();
        if(body.startsWith('<!DOCTYPE') || body.startsWith('<html')) return false;
        return true;
      }
      catch(_){
        return false;
      }
    }

    static Future<List<String>> _lookupPool(String? currentOrigin) async{
      if(currentOrigin == null) return [];
      try{
        final json = await InstitutesRequest.fetchInstitudesJSON();
        if(json == null) return [];
        for(final institute in InstitutesRequest.getDataFromInstitudesJSON(json)){
          if(institute.Fallbacks.isEmpty) continue;
          final pool = [institute.URL, ...institute.Fallbacks];
          if(pool.any((u) => originOf(u) == currentOrigin)){
            return pool;
          }
        }
      }
      catch(_){ }
      return [];
    }

    /// Tokens and cookies are issued per host, so the saved credentials have to be
    /// replayed against the new one before anything else will work.
    static Future<bool> trySwitch() async{
      // Also stops the login inside a switch from recursing back into here.
      if(_switching) return false;

      final current = storage.DataCache.getInstituteUrl();
      final username = storage.DataCache.getUsername();
      final password = storage.DataCache.getPassword();

      if(current == null || current.isEmpty) return false;
      if(username == null || username.isEmpty || password == null || password.isEmpty) return false;
      if(storage.DataCache.getIsDemoAccount() ?? false) return false;

      final currentOrigin = originOf(current);
      var pool = storage.DataCache.getInstituteFallbackUrls();
      if(pool.isEmpty){
        pool = await _lookupPool(currentOrigin);
        if(pool.isNotEmpty){
          await storage.DataCache.setInstituteFallbackUrls(pool);
        }
      }
      if(pool.isEmpty) return false;

      _switching = true;
      try{
        for(final candidate in pool){
          final candidateOrigin = originOf(candidate);
          if(candidateOrigin == null || candidateOrigin == currentOrigin) continue;
          if(!await _isAlive(candidate)) continue;

          final target = swapOrigin(current, candidateOrigin);
          if(target == null) continue;

          // Leaves the existing session untouched unless the new host accepts the
          // credentials, so a failed attempt cannot log the user out.
          final result = await InstitutesRequest.validateLoginCredentialsUrl(target, username, password);
          if(result == 1){
            debug.log('Institute endpoint switched to $candidateOrigin');
            CalendarRequest.invalidateTrainingId();
            return true;
          }
        }
      }
      catch(e){
        debug.log('Endpoint switch failed: $e');
      }
      finally{
        _switching = false;
      }
      return false;
    }
  }
  
  class _APIRequest{
    // POST-REQUEST for old API and modern login
    static Future<String> postRequest(Uri url, String requestBody,{String? bearerToken, bool isRetry = false}) async{
      // dart:io has no web implementation; the demo build never makes these calls anyway.
      if(!AppPlatform.isWeb) HttpOverrides.global = NeptunCerts.getCerts();
  
      final client = http.Client();
      final request = http.Request('POST', url);

      request.headers['Content-Type'] = 'application/json';
      if (bearerToken != null && bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      request.body = requestBody;

      var response;
      try{
        response = await client.send(request).then((response) {
          // Read and return the response
          return response.stream.bytesToString();
        });

        if (response != null) {
          String responseString = response.toString().trim();
          if (responseString.startsWith('<!DOCTYPE html') || responseString.startsWith('<html')){
            client.close();
            return '{"ErrorMessage": "Hibás URL vagy a Neptun szervere weboldalt küldött válaszként"}';
          }
        }
      }
      catch(error){
        client.close();
        if(!isRetry && await InstituteFailover.trySwitch()){
          final rebuilt = InstituteFailover.rebuild(url);
          if(rebuilt != null){
            final refreshed = bearerToken == null || bearerToken.isEmpty
                ? bearerToken
                : await storage.DataCache.getAccessToken();
            return postRequest(rebuilt, requestBody, bearerToken: refreshed, isRetry: true);
          }
        }
        return '{"ErrorMessage": "Hálózati hiba: $error"}';
      }

      // Close the client when done
      client.close();
  
      return response ?? '{}';
    }

    static Future<http.Response> postRequestRaw(Uri url, String requestBody,{String? bearerToken, String? cookie, bool isRetry = false}) async {
      // dart:io has no web implementation; the demo build never makes these calls anyway.
      if(!AppPlatform.isWeb) HttpOverrides.global = NeptunCerts.getCerts();
  
      final client = http.Client();
      final request = http.Request('POST', url);

      request.headers['Content-Type'] = 'application/json';
      if (bearerToken != null && bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      if (cookie != null && cookie.isNotEmpty) {
        request.headers['Cookie'] = cookie;
      }
      request.body = requestBody;

      try {
        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);
        client.close();
        return response;
      } catch (e) {
        client.close();
        if(!isRetry && await InstituteFailover.trySwitch()){
          final rebuilt = InstituteFailover.rebuild(url);
          final refreshedToken = storage.DataCache.getAccessToken();
          final refreshedCookie = storage.DataCache.getSessionCookie();
          if(rebuilt != null){
            return postRequestRaw(
              rebuilt,
              requestBody,
              bearerToken: refreshedToken ?? bearerToken,
              cookie: refreshedCookie ?? cookie,
              isRetry: true,
            );
          }
        }
        rethrow;
      }
    }

    static void _extractAndSaveCookiesAndTokens(http.Response response, String username) {
      final setCookie = response.headers['set-cookie'];
      if (setCookie == null || setCookie.isEmpty) return;

      // Extract device cookie: devicecookie-<BASE64_NEPTUN_CODE>=<VALUE>
      final deviceCookieRegExp = RegExp(r'devicecookie-[a-zA-Z0-9+/=]+=([a-zA-Z0-9+/=]+)');
      final deviceCookieMatch = deviceCookieRegExp.firstMatch(setCookie);
      if (deviceCookieMatch != null) {
        final cookieValue = deviceCookieMatch.group(1);
        storage.DataCache.setDeviceCookie(username, cookieValue);
      }

      // Session cookie: <GUID>=<JWT>. GetNewTokens needs the whole pair, so the name is kept too.
      final refreshTokenRegExp = RegExp(r'([^=;\s,]+)=(eyJ[a-zA-Z0-9\-_\.]+)');
      final refreshTokenMatch = refreshTokenRegExp.firstMatch(setCookie);
      if (refreshTokenMatch != null) {
        storage.DataCache.setRefreshToken(refreshTokenMatch.group(2));
        storage.DataCache.setSessionCookie(refreshTokenMatch.group(0));
      }
    }

    static bool _isRefreshingToken = false;

    static Future<bool> tryTokenRefresh() async {
      try {
        // GetNewTokens authenticates with the *access* token plus the session cookie;
        // either one alone is rejected, and no 2FA code is involved.
        final accessToken = await storage.DataCache.getAccessToken();
        final sessionCookie = storage.DataCache.getSessionCookie();
        if (accessToken == null || accessToken.isEmpty || sessionCookie == null || sessionCookie.isEmpty) {
          return false;
        }

        final baseUrl = storage.DataCache.getInstituteUrl();
        if (baseUrl == null || baseUrl.isEmpty) {
          return false;
        }

        String cookieHeader = sessionCookie;
        final username = storage.DataCache.getUsername();
        if (username != null && username.isNotEmpty) {
          final deviceCookie = await storage.DataCache.getDeviceCookie(username);
          if (deviceCookie != null && deviceCookie.isNotEmpty) {
            final b64 = conv.base64.encode(conv.utf8.encode(username.toUpperCase()));
            cookieHeader = '$cookieHeader; devicecookie-$b64=$deviceCookie';
          }
        }

        final refreshUrl = Uri.parse("$baseUrl/api/Account/GetNewTokens");
        final response = await postRequestRaw(refreshUrl, "{}", bearerToken: accessToken, cookie: cookieHeader);

        if (response.statusCode == 200) {
          final bodyJson = conv.jsonDecode(response.body);
          // The token sits at the root here, unlike Account/Authenticate which nests it under "data".
          final newAccessToken = bodyJson["accessToken"] ?? bodyJson["data"]?["accessToken"];
          if (newAccessToken != null) {
            await storage.DataCache.setAccessToken(newAccessToken);
            CalendarRequest.invalidateTrainingId();

            if (username != null) {
              _extractAndSaveCookiesAndTokens(response, username);
            }
            return true;
          }
        }
      } catch (e) {
        debug.log("Error during token refresh: $e");
      }
      return false;
    }

    static Future<String> getRequest(Uri url, {required String bearerToken, bool isRetry = false}) async {
      // dart:io has no web implementation; the demo build never makes these calls anyway.
      if(!AppPlatform.isWeb) HttpOverrides.global = NeptunCerts.getCerts();
      final client = http.Client();
      final request = http.Request('GET', url);
      request.headers['Authorization'] = 'Bearer $bearerToken';
      request.headers['Content-Type'] = 'application/json';

      try {
        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);
        client.close();

        // Ha a token lejárt:
        if ((response.statusCode == 401 || response.body.contains('"statusCode": 401') || response.body.contains('Authorization has been denied')) && !isRetry) {

          // --- ÚJ VERSENYHELYZET GÁTLÓ LOGIKA ---
          if (!_isRefreshingToken) {
            _isRefreshingToken = true; // Bezárjuk a lakatot
            debug.log("Token lejárt! Automatikus újra-bejelentkezés indítása...");

            bool refreshSuccess = false;
            if (storage.DataCache.getIsModernApi()) {
              refreshSuccess = await tryTokenRefresh();
            }

            if (!refreshSuccess) {
              final username = storage.DataCache.getUsername()!;
              final password = storage.DataCache.getPassword()!;
              final baseUrl = storage.DataCache.getInstituteUrl()!;

              await InstitutesRequest.validateLoginCredentialsUrl(baseUrl, username, password);
            }

            _isRefreshingToken = false; // Kinyitjuk a lakatot
          } else {
            // Ha egy másik fül már frissíti a tokent, várunk rá!
            debug.log("Egy másik fül már frissít, várakozás...");
            while (_isRefreshingToken) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }
          // ----------------------------------------

          // Mindenki megkapja az új tokent, és újra próbálkozik
          final newToken = await storage.DataCache.getAccessToken();
          return await getRequest(url, bearerToken: newToken!, isRetry: true);
        }

        return response.body;
      } catch (e) {
        client.close();
        if(!isRetry && await InstituteFailover.trySwitch()){
          final rebuilt = InstituteFailover.rebuild(url);
          final refreshed = await storage.DataCache.getAccessToken();
          if(rebuilt != null && refreshed != null){
            return await getRequest(rebuilt, bearerToken: refreshed, isRetry: true);
          }
        }
        return '{"ErrorMessage": "$e"}';
      }
    }

    static String getGenericPostData(String username, String password){
      return
        '{'
          '"UserLogin":"$username",'
          '"Password":"$password"'
        '}';
    }
  
    static Future<List<Term>> _getTermIDs() async{
      if(storage.DataCache.getIsDemoAccount()!){
        return <Term>[Term(70876, 'DEMO Félév')];
      }
      return getTerms();
    }

    static Future<List<Term>> getTerms() async{
      if(storage.DataCache.getIsDemoAccount()!){
        return <Term>[Term(70876, 'DEMO Félév')];
      }
      final username = storage.DataCache.getUsername();
      final password = storage.DataCache.getPassword();
      final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.PERIODTERMS_URL);
      final request = await _APIRequest.postRequest(url, _APIRequest.getGenericPostData(username!, password!));

      final decoded = conv.json.decode(request);
      if (decoded['PeriodTermsList'] == null) return [];
      List<dynamic> termList = decoded['PeriodTermsList'];



      List<Term> terms = [];
      for (var term in termList){
        final map = term as Map<String, dynamic>;
        terms.add(Term(map['Id'], map['TermName']));
      }
      return terms;
    }
  }
  
  class InstitutesRequest{
    static Future<List<dynamic>?> fetchInstitudesJSON() async{
      //return _APIRequest.postRequest(Uri.parse(URLs.INSTITUTIONS_URL), '{}');
      var json;
      try{
        json = await getRawJsonWithNameUrlPairs();
      }
      catch(error){
      }
      return json;
    }

    static Future<List<dynamic>?> getRawJsonWithNameUrlPairs() async{
      final url = Uri.parse('https://raw.githubusercontent.com/Bali0531-RC/NHNK/refs/heads/main/universityNameUrlPairs.json');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return null;
      }

      Map<String, dynamic> jsonMap = conv.json.decode(response.body);
      return jsonMap["Institutes"];
    }
  
    static List<Institute> getDataFromInstitudesJSON(List<dynamic> jsonMap){
      var newList = <Institute>[].toList();
      for (var item in jsonMap){
        var item2 = item as Map<String, dynamic>;
        String name = item2['Name'];
        String url = item2['Url'] ?? "NULL";
        // Optional, and older releases parsing this same file simply ignore it.
        final rawFallbacks = item2['Fallbacks'];
        final fallbacks = rawFallbacks is List
            ? rawFallbacks.whereType<String>().where((e) => e.trim().isNotEmpty).toList()
            : <String>[];
        if(url != "NULL" && name != "DEMO") { //remove obsolete or non existent entries
          newList.add(Institute(name, url, fallbacks));
        }
      }
      return newList;
    }
    static Future<int> validateLoginCredentials(Institute institute, String username, String password) async{
      // Stores the primary too, so a switch away from it can later switch back.
      await storage.DataCache.setInstituteFallbackUrls(
        institute.Fallbacks.isEmpty ? [] : [institute.URL, ...institute.Fallbacks],
      );
      return validateLoginCredentialsUrl(institute.URL, username, password);
    }
    //
// --- 2FA
    static Future<int> validateLoginCredentialsUrl(String rawUrl, String username, String password) async {
      if(username == 'DEMO' && password == 'DEMO'){
        await storage.DataCache.setIsDemoAccount(1);
        return 1;
      }

      String url = rawUrl.trim();
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      bool containsAspx = url.toLowerCase().contains('.aspx');

      String baseUrl = url.replaceAll(RegExp(r'/login(\.aspx)?$', caseSensitive: false), '');
      baseUrl = baseUrl.replaceAll(RegExp(r'/MobileService\.svc$', caseSensitive: false), '');

      // Path normalization for specific institutions is handled by the modern API detection below.

      if (containsAspx) {

        bool success = await _tryOldLogin(baseUrl, username, password);
        return success ? 1 : 0;
      } else {
        return await _tryModernLogin(baseUrl, username, password);
      }
    }

    static Future<int> _tryModernLogin(String baseUrl, String username, String password) async {
      try {
        final modernApiUrl = Uri.parse("$baseUrl/api/Account/Authenticate");
        final body = conv.jsonEncode({
          "userName": username, "password": password,
          "captcha": "", "captchaIdentifier": "", "token": "", "LCID": 1038
        });

        // Load device cookie if exists
        final savedCookieVal = await storage.DataCache.getDeviceCookie(username);
        String? cookieHeader;
        if (savedCookieVal != null && savedCookieVal.isNotEmpty) {
          final b64 = conv.base64.encode(conv.utf8.encode(username.toUpperCase()));
          cookieHeader = 'devicecookie-$b64=$savedCookieVal';
        }

        final responseRaw = await _APIRequest.postRequestRaw(modernApiUrl, body, cookie: cookieHeader);
        final response = conv.jsonDecode(responseRaw.body);

        // Extract and save cookies/tokens
        _APIRequest._extractAndSaveCookiesAndTokens(responseRaw, username);

        final is2fa = response["data"] != null && (response["data"]["isTwoFactorRequired"] == true || response["data"]["requiresTwoFactor"] == true);
        if (is2fa) {
          await storage.DataCache.setInstituteUrl(baseUrl);

          // With a stored secret the app can answer the challenge itself, so an expired
          // session does not force the user to retype a code.
          final secret = storage.DataCache.getTotpSecret();
          if (secret != null && secret.isNotEmpty) {
            final code = Totp.generate(secret);
            if (code != null && await submitTwoFactorCode(username, password, code)) {
              return 1;
            }
          }

          // Deliberately leaves the stored token alone: twoFactorLoginToken does not exist on
          // this API, so writing it here wiped a session that was still usable.
          return 2; // 2FA KELL
        }

        if (response["data"] != null && response["data"]["accessToken"] != null) {
          await storage.DataCache.setAccessToken(response["data"]["accessToken"]);
          await storage.DataCache.setIsModernApi(true);
          await storage.DataCache.setInstituteUrl(baseUrl);
          CalendarRequest.invalidateTrainingId();
          return 1;
        }
      } catch (e) { }
      return 0; // HIBA
    }


    static Future<bool> submitTwoFactorCode(String username, String password, String code) async {
      try {
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        final url = Uri.parse("$baseUrl/api/Account/Authenticate");
        final body = conv.jsonEncode({
          "userName": username,
          "password": password,
          "captcha":"",
          "captchaIdentifier":"",
          "token": code,
          "LCID":1038
        });

        // Load device cookie if exists
        final savedCookieVal = await storage.DataCache.getDeviceCookie(username);
        String? cookieHeader;
        if (savedCookieVal != null && savedCookieVal.isNotEmpty) {
          final b64 = conv.base64.encode(conv.utf8.encode(username.toUpperCase()));
          cookieHeader = 'devicecookie-$b64=$savedCookieVal';
        }

        final responseRaw = await _APIRequest.postRequestRaw(url, body, cookie: cookieHeader);
        final response = conv.jsonDecode(responseRaw.body);

        // Extract and save cookies/tokens
        _APIRequest._extractAndSaveCookiesAndTokens(responseRaw, username);

        if (response["data"] != null && response["data"]["accessToken"] != null) {
          await storage.DataCache.setAccessToken(response["data"]["accessToken"]);
          await storage.DataCache.setIsModernApi(true);
          CalendarRequest.invalidateTrainingId();
          return true;
        }
      } catch (e) { }
      return false;
    }
    static Future<bool> _tryOldLogin(String baseUrl, String username, String password) async {
      try {
        final oldApiUrl = Uri.parse("$baseUrl/MobileService.svc" + URLs.TRAININGS_URL);
        final request = await _APIRequest.postRequest(
            oldApiUrl,
            _APIRequest.getGenericPostData(username, password)
        );

        if (request.trim().startsWith('{')) {
          final decodedResponse = conv.json.decode(request);
          if (decodedResponse["ErrorMessage"] == null) {
            await storage.DataCache.setIsModernApi(false);
            await storage.DataCache.setInstituteUrl("$baseUrl/MobileService.svc");
            return true;
          }
        }
      } catch (e) { }
      return false;
    }

    static Future<int?> getFirstStudyweek() async{
      final periods = await PeriodsRequest.getPeriods();
      if(storage.DataCache.getIsDemoAccount()!){
        return DateTime(2024, 9, 1).millisecondsSinceEpoch;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if(periods == null){
        return null;
      }
  
      PeriodEntry? period;
      int neededExtraWeeks = 0;
      for (var item in periods){
        if(item.name.toLowerCase().contains('végleges tárgyjelentkezés')){
          if(item.startEpoch <= now || period != null && item.startEpoch <= now && item.startEpoch > period.startEpoch){
            period = item;
            neededExtraWeeks = 0;
          }
        }
      }
      if(period == null){
        for (var item in periods){
          if(item.name.toLowerCase().contains('bejelentkezési időszak')){
            if(item.startEpoch <= now || period != null && item.startEpoch <= now && item.startEpoch > period.startEpoch){
              period = item;
              neededExtraWeeks = 1;
            }
          }
        }
        if(period == null){
          return null;
        }
      }
  
      //final startDate = DateTime.fromMillisecondsSinceEpoch(period.startEpoch);
      final date = DateTime.fromMillisecondsSinceEpoch(period.endEpoch);
      int difference = date.weekday - DateTime.monday;

      final roundedDate = date.subtract(Duration(days: difference)).add(Duration(days: 7 * neededExtraWeeks));

      return roundedDate.millisecondsSinceEpoch;
    }
  }

class CalendarRequest {
  static String? _cachedTrainingId;
  static int _sessionGeneration = 0;

  static int get sessionGeneration => _sessionGeneration;

  // Neptun regenerates studentTrainingId on every login, so any new session invalidates it.
  static void invalidateTrainingId() {
    _cachedTrainingId = null;
    _sessionGeneration++;
  }

  static Future<String?> getStudentTrainingId({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _cachedTrainingId = null;
    }
    if (_cachedTrainingId != null) return _cachedTrainingId;
    if (!(storage.DataCache.getIsModernApi())) return null;

    try {
      final token = await storage.DataCache.getAccessToken();
      String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
      final url = Uri.parse("$baseUrl/api/Calendar/GetStudentTrainings");

      final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
      final decoded = conv.json.decode(responseRaw);

      if (decoded['data'] != null && decoded['data'].isNotEmpty) {
        for (var training in decoded['data']) {
          if (training['actualStudentTraining'] == true) {
            _cachedTrainingId = training['studentTrainingId'];
            return _cachedTrainingId;
          }
        }
        _cachedTrainingId = decoded['data'][0]['studentTrainingId'];
        return _cachedTrainingId;
      }
    } catch (e) { }
    return null;
  }

  static List<CalendarEntry>? _icsFallbackCache;
  static int _icsFallbackFetchedMs = 0;

  /// Whole-semester timetable from the personal iCal export, rather than the one
  /// week the calendar view holds.
  static Future<List<CalendarEntry>?> fetchFullTimetable() => _fetchIcsFallback();

  /// Some institutions leave GetCalendarEvents empty even though the timetable exists;
  /// the personal iCal export is populated in that case, so it is used as a fallback.
  static Future<List<CalendarEntry>?> _fetchIcsFallback() async {
    const int cacheTtlMs = 6 * 60 * 60 * 1000;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (_icsFallbackCache != null && now - _icsFallbackFetchedMs < cacheTtlMs) {
      return _icsFallbackCache;
    }

    try {
      // The export link carries its own token, so it keeps working with no session at all.
      String? icsUrl = storage.DataCache.getIcsExportUrl();

      if (icsUrl == null || icsUrl.isEmpty) {
        final token = await storage.DataCache.getAccessToken();
        final String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        if (token == null || token.isEmpty || baseUrl.isEmpty) return null;

        final linkUrl = Uri.parse("$baseUrl/api/Calendar/GetLinksForCalendarExport");
        final decoded = conv.json.decode(await _APIRequest.getRequest(linkUrl, bearerToken: token));
        icsUrl = decoded['data']?['urlForWebCalendars'];
        if (icsUrl == null || icsUrl.isEmpty) return null;
        await storage.DataCache.setIcsExportUrl(icsUrl);
      }

      final resp = await http.get(Uri.parse(icsUrl));
      if (resp.statusCode != 200) {
        // A regenerated link invalidates the old one; drop it so the next call re-fetches.
        await storage.DataCache.setIcsExportUrl(null);
        return null;
      }

      final entries = parseIcsEntries(conv.utf8.decode(resp.bodyBytes));
      _icsFallbackCache = entries;
      _icsFallbackFetchedMs = now;
      return entries;
    } catch (e) {
      debug.log("iCal tartal\u00e9k lek\u00e9r\u00e9s hiba: $e");
    }
    return null;
  }

  // "Programoz\u00e1s I. ( - HNV_01) - Heckl Istv\u00e1n - Tan\u00f3ra"
  static final RegExp _icsSummary = RegExp(r'^(.*?)\s*\(\s*([^()]*?)\s*\)(?:\s*-\s*([^-]*?))?(?:\s*-\s*([^-]*))?$');

  static List<CalendarEntry> parseIcsEntries(String ics) {
    final List<CalendarEntry> out = [];
    String? start, end, location, summary;

    for (var raw in ics.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line == 'BEGIN:VEVENT') {
        start = end = location = summary = null;
      } else if (line == 'END:VEVENT') {
        if (start == null || end == null) continue;
        final startDt = DateTime.tryParse(start);
        final endDt = DateTime.tryParse(end);
        if (startDt == null || endDt == null) continue;

        String title = summary ?? 'Ismeretlen';
        String teacher = 'Nincs megadva';
        String code = '-';
        int type = 0;

        final m = _icsSummary.firstMatch(title);
        if (m != null) {
          title = (m.group(1) ?? title).trim();
          teacher = (m.group(3) ?? 'Nincs megadva').trim();
          final kind = (m.group(4) ?? '').toLowerCase();
          if (kind.contains('vizsga')) type = 1;

          // The bracket holds "<subjectCode> - <courseCode>", either of which may be blank.
          final parts = (m.group(2) ?? '').split('-').map((p) => p.trim()).where((p) => p.isNotEmpty);
          code = parts.isEmpty ? '-' : parts.join(' - ');
        }

        out.add(CalendarEntry.fromModern(
          startEpoch: startDt.millisecondsSinceEpoch,
          endEpoch: endDt.millisecondsSinceEpoch,
          location: (location == null || location.isEmpty) ? 'Nincs megadva' : location,
          title: title.isEmpty ? 'Ismeretlen' : title,
          eventType: type,
          subjectCode: code.isEmpty ? '-' : code,
          teacher: teacher.isEmpty ? 'Nincs megadva' : teacher,
          classInstanceId: '',
          taskId: '',
        ));
      } else if (line.startsWith('DTSTART')) {
        start = line.substring(line.indexOf(':') + 1);
      } else if (line.startsWith('DTEND')) {
        end = line.substring(line.indexOf(':') + 1);
      } else if (line.startsWith('LOCATION:')) {
        location = line.substring(9).trim();
      } else if (line.startsWith('SUMMARY:')) {
        summary = line.substring(8).trim();
      }
    }
    return out;
  }

  static List<CalendarEntry> getCalendarEntriesFromJSON(String jsonString) {
    if (jsonString == '{}') return [];
    final decoded = conv.json.decode(jsonString);
    List<CalendarEntry> list = [];
    // The demo feed is emitted in the modern shape so it skips the legacy DST correction.
    if (storage.DataCache.getIsModernApi() || (storage.DataCache.getIsDemoAccount() ?? false)) {
      if (decoded['calendarData'] != null) {
        for (var item in decoded['calendarData']) {
          list.add(CalendarEntry.fromModern(
            startEpoch: item['start_ms'],
            endEpoch: item['end_ms'],
            location: item['location'] ?? "Nincs megadva",
            title: item['title'] ?? "Nincs cím",
            eventType: item['type'],
            subjectCode: item['subjectCode'],
            teacher: item['teacher'],
            classInstanceId: item['classInstanceId'],
            taskId: item['taskId'],
          ));
        }
      }
      return list;
    }

    if (decoded['calendarData'] != null) {
      for (var item in decoded['calendarData']) {
        String rawStart = item['start']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
        String rawEnd = item['end']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';

        list.add(CalendarEntry(
          rawStart.isEmpty ? '0' : rawStart,
          rawEnd.isEmpty ? '0' : rawEnd,
          item['location'] ?? "Nincs megadva",
          item['title'] ?? "Nincs cím",
          item['type'] == 1,
        ));
      }
    }
    return list;
  }

  static Future<String> makeCalendarRequest(String calendarJson) async {
    if (storage.DataCache.getIsDemoAccount()!) {
      return _demoCalendarJson(calendarJson);
    }
    if (storage.DataCache.getHasICSFile()!) {
      return '{}';
    }

    if (storage.DataCache.getIsModernApi()) {
      final oldPayload = conv.json.decode(calendarJson);
      final startDateRaw = (oldPayload['startDate'] ?? oldPayload['StartDate']).toString();
      final endDateRaw = (oldPayload['endDate'] ?? oldPayload['EndDate']).toString();

      final numRegex = RegExp(r'\d+');
      final startEpoch = int.parse(numRegex.firstMatch(startDateRaw)!.group(0)!);
      final endEpoch = int.parse(numRegex.firstMatch(endDateRaw)!.group(0)!);

      // Used whenever the JSON endpoint yields nothing, including when the session is gone.
      Future<String> fromIcsOnly() async {
        final fallback = await _fetchIcsFallback();
        final List<Map<String, dynamic>> list = [];
        if (fallback != null) {
          for (var e in fallback) {
            if (e.startEpoch < startEpoch || e.startEpoch > endEpoch) continue;
            list.add({
              'start_ms': e.startEpoch,
              'end_ms': e.endEpoch,
              'location': e.location,
              'title': e.title,
              'type': e.eventType,
              'subjectCode': e.subjectCode,
              'teacher': e.teacher,
              'classInstanceId': '',
              'taskId': '',
            });
          }
          list.sort((a, b) => (a['start_ms'] as int).compareTo(b['start_ms'] as int));
        }
        return conv.jsonEncode({"calendarData": list});
      }

      try {
        final startIso = DateTime.fromMillisecondsSinceEpoch(startEpoch).toIso8601String();
        final endIso = DateTime.fromMillisecondsSinceEpoch(endEpoch).toIso8601String();

        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        String responseRaw = "";
        bool needsReAuth = false;

        bool dispClasses = storage.DataCache.getDisplayClasses() ?? true;
        bool dispExams = storage.DataCache.getDisplayExams() ?? true;
        bool dispPeriods = storage.DataCache.getDisplayPeriods() ?? true;

        String buildEventsUrl(String trainingId) =>
            "$baseUrl/api/Calendar/GetCalendarEvents?startDate=$startIso&endDate=$endIso"
            "&studentTrainingIds[0]=$trainingId"
            "&displayClasses=$dispClasses&displayExams=$dispExams"
            "&displayOnlineMeetings=false&displayOtherEvents=true"
            "&displayPeriods=$dispPeriods&displayTasks=true";

        try {
          final generationBefore = sessionGeneration;
          final trainingId = await getStudentTrainingId(forceRefresh: false);
          if (trainingId != null) {
            final token = await storage.DataCache.getAccessToken();

            final url = Uri.parse(buildEventsUrl(trainingId));

            responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);

            if (responseRaw.contains('"statusCode":410') || responseRaw.contains('Authorization has been denied') || responseRaw.contains('"statusCode": 401')) {
              needsReAuth = true;
            }
            // A refresh mid-request rotates the session, which retires the training ID we just used.
            if (sessionGeneration != generationBefore) {
              needsReAuth = true;
            }
          } else {
            needsReAuth = true;
          }
        } catch (e) {
          needsReAuth = true;
        }

        if (needsReAuth) {
          debug.log("Naptár: Lejárt token/ID érzékelve. Újra-azonosítás indul...");
          // Refresh first: a full re-login re-triggers the 2FA prompt.
          bool reauthed = await _APIRequest.tryTokenRefresh();
          if (!reauthed) {
            final username = storage.DataCache.getUsername();
            final password = storage.DataCache.getPassword();
            if (username == null || username.isEmpty || password == null || password.isEmpty) {
              return await fromIcsOnly();
            }
            await InstitutesRequest.validateLoginCredentialsUrl(baseUrl, username, password);
          }

          final newTrainingId = await getStudentTrainingId(forceRefresh: true);
          if (newTrainingId == null) return await fromIcsOnly();

          final newToken = await storage.DataCache.getAccessToken();
          final retryUrl = Uri.parse(buildEventsUrl(newTrainingId));

          responseRaw = await _APIRequest.getRequest(retryUrl, bearerToken: newToken!);
        }

        final newApiData = conv.json.decode(responseRaw);
        List<Map<String, dynamic>> mappedList = [];

        if (newApiData['data'] != null) {
          var dataPart = newApiData['data'];
          Iterable items = dataPart is List ? dataPart : [dataPart];

          for (var event in items) {
            final eventStartEpoch = DateTime.parse(event['startDate']).millisecondsSinceEpoch;
            final eventEndEpoch = DateTime.parse(event['endDate']).millisecondsSinceEpoch;

            mappedList.add({
              'start_ms': eventStartEpoch,
              'end_ms': eventEndEpoch,
              'location': event['rooms'] ?? event['room'] ?? 'Nincs megadva',
              'title': event['name'] ?? event['subjectName'] ?? 'Ismeretlen',
              'type': event['eventTypeId'] ?? 0,
              'subjectCode': event['courseCode'] ?? '-',
              'teacher': event['courseTutor'] ?? 'Nincs megadva',
              'classInstanceId': event['classInstanceId'] ?? '',
              'taskId': event['id'] ?? event['taskId'] ?? event['midTermTaskId'] ?? '',
            });
          }
        }

        if (mappedList.isEmpty) {
          return await fromIcsOnly();
        }

        return conv.jsonEncode({"calendarData": mappedList});

      } catch (e) {
        debug.log("Naptár lekérési hiba: $e");
        try {
          return await fromIcsOnly();
        } catch (_) {
          return '{"calendarData": []}';
        }
      }
    } else {

      final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.CALENDAR_URL);
      final request = await _APIRequest.postRequest(url, calendarJson);
      return request;
    }
  }


  static Future<Map<String, String>> getCourseDetails(String classInstanceId) async {
    if (storage.DataCache.getIsModernApi() != true) {
      return {"room": "Nem támogatott (Régi API)", "teacher": "Nem támogatott"};
    }

    final cachedRoom = await storage.getString('room_$classInstanceId');
    final cachedTeacher = await storage.getString('teacher_$classInstanceId');

    if (!(storage.DataCache.getHasNetwork())) {
      if (cachedRoom != null) {
        return {"room": cachedRoom, "teacher": cachedTeacher ?? "Nincs tanár"};
      }
      return {"room": "Nincs internet", "teacher": "Offline mód"};
    }

    try {
      final token = await storage.DataCache.getAccessToken();
      String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

      final url = Uri.parse("$baseUrl/api/Calendar/GetCourseDetails?classInstanceId=$classInstanceId&webexMeetingId=null");
      final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
      final decoded = conv.json.decode(responseRaw);

      if (decoded['data'] != null) {
        final r = decoded['data']['room'] ?? "Nincs terem";
        final t = decoded['data']['courseTutor'] ?? "Nincs tanár";


        await storage.saveString('room_$classInstanceId', r);
        await storage.saveString('teacher_$classInstanceId', t);

        return {"room": r, "teacher": t};
      }
    } catch (e) {
      debug.log("Hiba az óra részleteinek lekérésekor: $e");
    }


    if (cachedRoom != null) {
      return {"room": cachedRoom, "teacher": cachedTeacher ?? "Nincs tanár"};
    }

    return {"room": "Hiba a betöltésnél", "teacher": "Hiba a betöltésnél"};
  }


  //missing details definition. pulls class location and uh... idk just fills the class
  static Future<void> fillMissingDetails(List<CalendarEntry> entries, Function onUpdate) async {
    bool hasNetwork = storage.DataCache.getHasNetwork();
    String? token;
    String baseUrl = '';

    if (hasNetwork) {
      token = await storage.DataCache.getAccessToken();
      baseUrl = storage.DataCache.getInstituteUrl() ?? '';
    }

    bool didUpdateUI = false;
    // Régi: for (var entry in entries) {
    for (var entry in entries.toList()) {
      if (entry.isTask && entry.taskId != null && entry.taskId!.isNotEmpty) {
        final cachedSubject = await storage.getString('task_sub_${entry.taskId}');


        if (cachedSubject != null && cachedSubject.isNotEmpty) {
          if (entry.location != cachedSubject) {
            entry.location = cachedSubject;
            didUpdateUI = true;
          }
          continue;
        }

        if (hasNetwork && token != null) {
          try {
            final url = Uri.parse("$baseUrl/api/Tasks/GetTaskDetail?midtermTaskId=${entry.taskId}");
            final responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
            final decoded = conv.json.decode(responseRaw);

            if (decoded['data'] != null) {
              final subject = decoded['data']['subjectName'] ?? "Ismeretlen tárgy";
              final type = decoded['data']['midtermTaskType'] ?? "Feladat";
              final result = decoded['data']['midtermResult'] ?? "Nincs eredmény";

              entry.location = subject;
              didUpdateUI = true;


              await storage.saveString('task_sub_${entry.taskId}', subject);
              await storage.saveString('task_type_${entry.taskId}', type);
              await storage.saveString('task_res_${entry.taskId}', result);

              onUpdate();
            }
          } catch(e) {}
          await Future.delayed(const Duration(milliseconds: 75));
        }
        continue;
      }
      if (entry.classInstanceId == null || entry.classInstanceId!.isEmpty) continue;

      final cachedRoom = await storage.getString('room_${entry.classInstanceId}');
      final cachedTeacher = await storage.getString('teacher_${entry.classInstanceId}');

      if (cachedRoom != null && cachedRoom.isNotEmpty && cachedRoom != "Nincs terem") {
        if (entry.location != cachedRoom || entry.teacher != cachedTeacher) {
          entry.location = cachedRoom;
          entry.teacher = cachedTeacher ?? "Nincs tanár";
          didUpdateUI = true;
        }
        continue;
      }

      if (hasNetwork && token != null) {
        try {
          final url = Uri.parse("$baseUrl/api/Calendar/GetCourseDetails?classInstanceId=${entry.classInstanceId}&webexMeetingId=null");
          final responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
          final decoded = conv.json.decode(responseRaw);

          if (decoded['data'] != null) {
            final r = decoded['data']['room'];
            final finalRoom = (r == null || r.toString().trim().isEmpty) ? "Nincs terem" : r.toString();
            final t = decoded['data']['courseTutor'] ?? "Nincs tanár";

            entry.location = finalRoom;
            entry.teacher = t;
            didUpdateUI = true;

            await storage.saveString('room_${entry.classInstanceId}', finalRoom);
            await storage.saveString('teacher_${entry.classInstanceId}', t);

            onUpdate();
          }
        } catch(e) {}

        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    if (didUpdateUI) {
      onUpdate();
    }
  }

    // weekOffset 1 means the current week, matching HomePageState.currentWeekOffset.
    // Pure calendar arithmetic: Duration-based day maths drifts across DST boundaries.
    static DateTime weekStartFor(int weekOffset){
      final DateTime now = DateTime.now();
      final DateTime thisMonday = DateTime(now.year, now.month, now.day - (now.weekday - DateTime.monday));
      return DateTime(thisMonday.year, thisMonday.month, thisMonday.day + ((weekOffset - 1) * 7));
    }

    static DateTime weekEndFor(int weekOffset){
      final DateTime start = weekStartFor(weekOffset);
      return DateTime(start.year, start.month, start.day + 6, 23, 59, 59);
    }

    // Sandboxed demo timetable. Repeats the same teaching week around whichever week the
    // user paged to, so the calendar stays populated without touching the network.
    static String _demoCalendarJson(String requestJson){
      DateTime monday;
      try{
        final decoded = conv.json.decode(requestJson);
        monday = DateTime.fromMillisecondsSinceEpoch(decoded['demoWeekStart']);
      }
      catch(_){
        monday = weekStartFor(1);
      }

      Map<String, dynamic> entry(int day, int fromHour, int fromMin, int toHour, int toMin,
          String title, String location, String teacher, String code, int type){
        return {
          'start_ms': DateTime(monday.year, monday.month, monday.day + day, fromHour, fromMin).millisecondsSinceEpoch,
          'end_ms': DateTime(monday.year, monday.month, monday.day + day, toHour, toMin).millisecondsSinceEpoch,
          'location': location,
          'title': title,
          'type': type,
          'subjectCode': code,
          'teacher': teacher,
          'classInstanceId': null,
          'taskId': null,
        };
      }

      return conv.json.encode({'calendarData': [
        entry(0, 8, 0, 9, 30, 'Analízis I. (előadás)', 'E-101', 'Dr. Kovács Anna', 'DEMO-MAT101', 0),
        entry(0, 10, 0, 11, 30, 'Programozás alapjai (gyakorlat)', 'L-204', 'Nagy Péter', 'DEMO-INF102', 0),
        entry(1, 12, 0, 13, 30, 'Diszkrét matematika (előadás)', 'E-102', 'Dr. Szabó Béla', 'DEMO-MAT110', 0),
        entry(2, 8, 0, 9, 30, 'Programozás alapjai (előadás)', 'E-101', 'Dr. Tóth Gábor', 'DEMO-INF102', 0),
        entry(2, 14, 0, 15, 30, 'Szaknyelvi kommunikáció', 'N-12', 'Kiss Judit', 'DEMO-ANG201', 0),
        entry(3, 10, 0, 11, 30, 'Számítógép-architektúrák', 'E-103', 'Dr. Varga Zsolt', 'DEMO-INF120', 0),
        entry(4, 9, 0, 11, 0, 'Analízis I. vizsga', 'A-201', 'Dr. Kovács Anna', 'DEMO-MAT101', 1),
      ]});
    }

    static String getCalendarOneWeekJSON(String username, String password, int weekOffset){
      if(storage.DataCache.getIsDemoAccount()!){
        // Only the week bounds matter offline; _demoCalendarJson builds the entries from them.
        return '{"demoWeekStart":${weekStartFor(weekOffset).millisecondsSinceEpoch}}';
      }

      final epochStart = weekStartFor(weekOffset).millisecondsSinceEpoch;
      final epochEnd = weekEndFor(weekOffset).millisecondsSinceEpoch;

      return
        '{'
          '"UserLogin":"$username",'
          '"Password":"$password",'
          '"Time":true,'
          '"Exam":true,'
          '"startDate":"/Date($epochStart)/",'
          '"endDate":"/Date($epochEnd)/",'
          '"TotalRowCount":-1'
        '}';
    }
  }

class MarkbookRequest{
  static Future<List<Subject>?> getMarkbookSubjects() async{
    if(storage.DataCache.getIsDemoAccount()!){
      return <Subject>[
        Subject(false, 1, 'DEMO tantárgy 1', 0, 4, 0),
        Subject(true, 4, 'DEMO szellemjegy', 1, 0, 0),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){ return []; }

    // --- MODERN API ÁG (Párhuzamos lekéréssel!) ---
    if (storage.DataCache.getIsModernApi() /*?? false*/) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        // 1. Félévek lekérése
        final termsUrl = Uri.parse("$baseUrl/api/TakenSubjects/Terms");
        final termsResponse = await _APIRequest.getRequest(termsUrl, bearerToken: token!);
        final termsDecoded = conv.json.decode(termsResponse);
        if (termsDecoded['data'] == null || termsDecoded['data'].isEmpty) return [];

        // Legutolsó félév kiválasztása
        String activeTermId = termsDecoded['data'].last['value'];

        // 2. Felvett tárgyak listájának lekérése
        final subjectsUrl = Uri.parse("$baseUrl/api/TakenSubjects?request.termId=$activeTermId&sortAndPage.firstRow=0&sortAndPage.lastRow=50");
        final subjectsResponse = await _APIRequest.getRequest(subjectsUrl, bearerToken: token);
        final subjectsDecoded = conv.json.decode(subjectsResponse);

        List<Subject> modernSubjects = [];

        if (subjectsDecoded['data'] != null) {
          final entries = (subjectsDecoded['data'] as List<dynamic>);

          // Fetched in small batches: firing every subject at once gets throttled by Neptun.
          const int batchSize = 6;
          for (int i = 0; i < entries.length; i += batchSize) {
            final batch = entries.skip(i).take(batchSize).map((item) {
              String subjectId = item['subjectId'];
              String subjectName = item['subjectName'] ?? 'Ismeretlen';
              int credit = item['subjectCredit'] ?? 0;
              return _fetchSubjectGrade(baseUrl, token, subjectId, activeTermId, subjectName, credit);
            }).toList();

            for (var res in await Future.wait(batch)) {
              if (res != null) {
                modernSubjects.add(res);
              }
            }
          }
        }
        return modernSubjects;
      } catch (e) {
        debug.log("Hiba a modern tárgyak lekérésekor: $e");
        return [];
      }
    }

    // --- RÉGI API ÁG (Ahol még él a /MobileService.svc) ---
    String responseJson = await _getMarkbookJSon();
    List<dynamic> markbooklistRaw = [];
    final decoded = conv.json.decode(responseJson);
    if (decoded['MarkBookList'] == null) return null;
    markbooklistRaw = decoded['MarkBookList'];

    if(responseJson.isEmpty || markbooklistRaw.isEmpty){ return null; }

    List<Subject> subjects = [];
    for (var markbook in markbooklistRaw){
      final markbookMap = markbook as Map<String, dynamic>;
      subjects.add(Subject(
          markbookMap['Completed'], markbookMap['Credit'], markbookMap['SubjectName'],
          markbookMap['ID'], parseTextToGrade(markbookMap['Values']), parseTextToFailstate(markbookMap['Signer'])
      ));
    }
    return subjects;
  }

  // --- ÚJ SEGÉDFÜGGVÉNY: Egy adott tárgy érdemjegyének letöltése ---
  static Future<Subject?> _fetchSubjectGrade(String baseUrl, String token, String subjectId, String termId, String subjectName, int credit) async {
    try {
      final url = Uri.parse("$baseUrl/api/SubjectCourse/GetSubjectDetails?subjectId=$subjectId&termId=$termId");
      final responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
      final decoded = conv.json.decode(responseRaw);

      if (decoded['data'] != null) {
        int grade = 0;
        bool isCompleted = false;

        if (decoded['data']['subjectResult'] != null) {
          var result = decoded['data']['subjectResult'];
          isCompleted = result['passed'] ?? false;

          // Ha van konkrét számes jegy (pl. 3)
          if (result['resultValue'] != null) {
            grade = result['resultValue'];
          }
          // Ha csak szöveg van (pl. "Megfelelt", "Jeles")
          else if (result['resultName'] != null) {
            grade = parseTextToGrade(result['resultName']);
          }
        }
        // Ha nincs subjectResult, de a statusText azt mondja "Teljesített"
        else if (decoded['data']['subjectStatus'] != null) {
          if (decoded['data']['subjectStatus']['statusText'] == 'Teljesített') {
            isCompleted = true;
            grade = 5; // Pipa fog megjelenni
          }
        }

        return Subject(isCompleted, credit, subjectName, 0, grade, 0);
      }
    } catch (e) {
      debug.log("Hiba a(z) $subjectName jegyének lekérésekor: $e");
    }
    return null;
  }

  static Future<String> _getMarkbookJSon() async{
    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.MARKBOOK_URL);
    final json = '{"UserLogin":"$username","Password":"$password","CurrentPage":1,"filter":{"TermID": 0},"TotalRowCount":-1}';
    return await _APIRequest.postRequest(url, json);
  }

  static int parseTextToFailstate(String failstate){
    RegExp regex = RegExp(r'(aláírva|megtagadva)');
    final matches = regex.allMatches(failstate.toLowerCase());
    if(matches.isEmpty) return 0;
    int best = 99;
    for(var match in matches){
      final result = (match.group(1) ?? '').trim().toLowerCase();
      if(result.isEmpty) return 0;
      switch (result){
        case "megtagadva": if(best > 1) best = 1; break;
        default: if(best > 0) best = 0; break;
      }
    }
    return best;
  }

  static bool isMark(String txt){
    switch(txt){
      case 'jeles': case 'jó': case 'közepes': case 'elégséges': case 'elégtelen': return true;
      default: return false;
    }
  }

  static int parseTextToGrade(String gradeTxt){
    RegExp regex = RegExp(r'(elégtelen|elégséges|közepes|jó|jeles|megfelelt)');
    final matches = regex.allMatches(gradeTxt.toLowerCase());
    if(matches.isEmpty) return 0;

    int latest = 0;
    for(var match in matches){
      final result = (match.group(1) ?? '').trim().toLowerCase();
      if(result.isEmpty) break;
      switch (result){
        case 'jeles': latest = 5; break;
        case 'jó': latest = 4; break;
        case 'közepes': latest = 3; break;
        case 'elégséges': latest = 2; break;
        case 'elégtelen': latest = 1; break;
        case 'megfelelt': latest = 5; break; // Pipa megjelenítéséhez
      }
    }
    return latest;
  }
}

class CashinRequest{
  static Future<List<CashinEntry>?> getAllCashins() async{
    if(storage.DataCache.getIsDemoAccount()!){
      final now = DateTime.now();
      return <CashinEntry>[
        CashinEntry(10000, DateTime(now.year + 1, now.month).millisecondsSinceEpoch, 'DEMO befizetés 1', "1", 'aktív'),
        CashinEntry(70, DateTime(now.year + 1, now.month).millisecondsSinceEpoch, 'DEMO befizetés 2', "2", 'teljesített'),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){
      return [];
    }


    if (storage.DataCache.getIsModernApi()/* ?? false*/) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        final url = Uri.parse("$baseUrl/api/Transactions/GetStudentPreviousTransactions?sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.transferDate=desc");

        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
        final decoded = conv.json.decode(responseRaw);

        List<CashinEntry> modernCashins = [];

        if (decoded['data'] != null) {
          for (var item in decoded['data']) {
            // JSON whole numbers decode as int, so a hard `as double` cast would throw.
            int amount = ((item['transactionValue'] as num?) ?? 0).round();
            if (item['sign'] == '-') {
              amount = -amount;
            }

            modernCashins.add(CashinEntry(
                amount,
                DateTime.parse(item['transferDate']).millisecondsSinceEpoch,
                item['transactionPayingType'] ?? 'Ismeretlen tranzakció',
                item['transactionId'] ?? 'ismeretlen_id',
                item['transactionStatus'] ?? 'Ismeretlen státusz'
            ));
          }
        }
        return modernCashins;
      } catch (e) {
        debug.log("Hiba a modern tranzakciók lekérésekor: $e");
        return [];
      }
    }


    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final json = '{"UserLogin":"$username","Password":"$password","TotalRowCount":-1}';
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.GETCASHIN_URL);

    List<CashinEntry> entries = _jsonToCashinEntry(await _APIRequest.postRequest(url, json));
    return entries;
  }

  static List<CashinEntry> _jsonToCashinEntry(String json){
    if(storage.DataCache.getIsDemoAccount()!){ return []; }
    List<CashinEntry> ls = [];
    try {
      final List<dynamic> cashins = conv.json.decode(json)['CashinDataRows'];
      for (var cashin in cashins) {
        ls.add(CashinEntry(
            cashin['amount'],
            int.parse(cashin['deadline'] == null ? '0' : cashin['deadline'].toString().replaceAll('/Date(', '').replaceAll(')/', '')),
            cashin['appellation'],
            cashin['ID'].toString(),
            cashin['status_name']
        ));
      }
    }
    catch (_){ return []; }
    return ls;
  }
}

class PeriodsRequest{

  static Future<List<PeriodEntry>?> getPeriods() async{
    if(storage.DataCache.getIsDemoAccount()!){
      final now = DateTime.now();
      return <PeriodEntry>[
        PeriodEntry('lejárt időszak', DateTime(now.year - 1, now.month, now.day - 2).millisecondsSinceEpoch, DateTime(now.year - 1, now.month, now.day + 1).millisecondsSinceEpoch, 1),
        PeriodEntry('bejelentkezési időszak', DateTime(now.year, now.month, now.day - 2).millisecondsSinceEpoch, DateTime(now.year, now.month, now.day +7).millisecondsSinceEpoch, 1),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){
      return [PeriodEntry('végleges tárgyjelentkezés', await ICSCalendar.getFirstEventStartMs(), await ICSCalendar.getFirstEventStartMs() + Duration(days: 365).inMilliseconds, 1)];
    }

    // --- MODERN API ÁG ---
    if (storage.DataCache.getIsModernApi()/* ?? false*/) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        // 1. Félévek (Terms) lekérése
        final termsUrl = Uri.parse("$baseUrl/api/Periods/GetTerms");
        final termsResponse = await _APIRequest.getRequest(termsUrl, bearerToken: token!);
        final termsDecoded = conv.json.decode(termsResponse);

        if (termsDecoded['data'] == null || termsDecoded['data'].isEmpty) return [];

        // 2. Legutolsó félév (pl. "2025/26/2") kiválasztása
        String activeTermId = termsDecoded['data'].last['value'];

        // 3. Időszakok lekérése az adott félévhez
        final periodsUrl = Uri.parse("$baseUrl/api/Periods/GetPeriods?request.termId=$activeTermId&sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.fromDate=asc");
        final periodsResponse = await _APIRequest.getRequest(periodsUrl, bearerToken: token);
        final periodsDecoded = conv.json.decode(periodsResponse);

        List<PeriodEntry> modernPeriods = [];
        if (periodsDecoded['data'] != null) {
          for (var item in periodsDecoded['data']) {
            modernPeriods.add(PeriodEntry(
                item['periodName'] ?? 'Ismeretlen időszak',
                DateTime.parse(item['fromDate']).millisecondsSinceEpoch,
                DateTime.parse(item['toDate']).millisecondsSinceEpoch,
                1 // partOfSemester fake adat (nem használja igazán a UI)
            ));
          }
        }
        return modernPeriods;

      } catch (e) {
        debug.log("Hiba a modern időszakok lekérésekor: $e");
        return [];
      }
    }

    // --- RÉGI API ÁG ---
    final terms = await _APIRequest._getTermIDs();
    if(terms.isEmpty) return <PeriodEntry>[PeriodEntry('Hiba lépett fel!\nNincs term id.', DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch, 1)];

    List<PeriodEntry> periods = <PeriodEntry>[];
    int cntperiod = terms.length;
    for(var term in terms){
      final jsonresult = await _getPeriodJSon(term.id);
      final result = conv.json.decode(jsonresult)['PeriodList'] as List<dynamic>;
      for(var period in result){
        final currPeriod = period as Map<String, dynamic>;
        periods.add(PeriodEntry(currPeriod['PeriodTypeName'], int.parse(currPeriod['FromDate'].toString().replaceAll('/Date(', '').replaceAll(')/', '')), int.parse(currPeriod['ToDate'].toString().replaceAll('/Date(', '').replaceAll(')/', '')), cntperiod));
      }
      cntperiod--;
    }
    return periods;
  }

  static Future<String> _getPeriodJSon(int termID) async{
    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.PERIODS_URL);
    final json = '{"UserLogin":"$username","Password":"$password","PeriodTermID":$termID,"TotalRowCount":-1}';
    return await _APIRequest.postRequest(url, json);
  }
}

class MailRequest{
  static const int _modernMailCountWindow = 200;

  static Future<List<int>> getUnreadMessagesAndAllMessages()async{
    // Every other endpoint short-circuits for the demo account; this one did not,
    // so demo mode still fired a request at whatever the institute URL resolved to.
    if(storage.DataCache.getIsDemoAccount() ?? false){
      return [2, 2, 2];
    }
    try{
      if (storage.DataCache.getIsModernApi()/* ?? false*/) {
        final token = await storage.DataCache.getAccessToken();
        final baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        if (token == null || token.isEmpty || baseUrl.isEmpty) {
          return [0, 0, 0];
        }

        // The modern API exposes no count endpoint, so the list itself is counted.
        final url = Uri.parse("$baseUrl/api/Message/GetReceivedMessages?firstRow=0&lastRow=$_modernMailCountWindow&filterType=0");
        final decoded = conv.json.decode(await _APIRequest.getRequest(url, bearerToken: token));
        final messages = decoded['data']?['receivedMessages'] as List<dynamic>?;
        if (messages == null) {
          return [0, 0, 0];
        }

        int unread = 0;
        for (var item in messages) {
          if (((item['unreadedPostCount'] ?? 0) as int) > 0) {
            unread++;
          }
        }
        return [unread, messages.length];
      }
      List<int> list = [];
      final json = await _getMailJson(0);
      var result = conv.json.decode(json)['NewMessagesNumber'];
      list.add(result);
      result = conv.json.decode(json)['TotalRowCount'];
      list.add(result);
      return list;
    }
    catch(_){
      return [0, 0, 0];
    }
  }

  static Future<List<MailEntry>?> getMails(int page) async{
    if(storage.DataCache.getIsDemoAccount()!){
      final now = DateTime.now();
      return <MailEntry>[
        MailEntry('Tárgy', 'Szöveg', 'DEMO feladó', now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch, false, "0"),
        MailEntry('DEMO', 'Demo Demo Demo', 'DEMO feladó', now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch, false, "1"),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){
      return [];
    }

    if (storage.DataCache.getIsModernApi()/* ?? false*/) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        int actualPage = page > 0 ? page - 1 : 0;
        int firstRow = actualPage * 20;
        int lastRow = firstRow + 20;

        final url = Uri.parse("$baseUrl/api/Message/GetReceivedMessages?firstRow=$firstRow&lastRow=$lastRow&filterType=0");
        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
        final decoded = conv.json.decode(responseRaw);

        List<MailEntry> modernMails = [];
        if (decoded['data'] != null && decoded['data']['receivedMessages'] != null) {
          for (var item in decoded['data']['receivedMessages']) {
            modernMails.add(MailEntry(
              item['subject'] ?? "Nincs tárgy",
              "A szöveg letöltéséhez kattints ide...",
              item['senderName'] ?? "Ismeretlen",
              DateTime.parse(item['lastPostDate']).millisecondsSinceEpoch,
              item['unreadedPostCount'] == 0,
              item['messageId'].toString(),
            ));
          }
        }
        return modernMails;
      } catch (e) {
        debug.log("Hiba a modern üzenetek lekérésekor: $e");
        return [];
      }
    }

    final request = await _getMailJson(page);
    List<MailEntry> mails = getMailEntrysJson(request);
    return mails;
  }

  static Future<String> _getMailJson(int page)async{
    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.MESSAGES_URL);
    final json = '{"UserLogin":"$username","Password":"$password","CurrentPage":$page,"TotalRowCount":-1,"MessageID":0,"MessageSortEnum":0}';
    return await _APIRequest.postRequest(url, json);
  }

  static List<MailEntry> getMailEntrysJson(String json){
    List<MailEntry> mails = [];
    final decoded = conv.json.decode(json);
    if (decoded['MessagesList'] == null) return [];
    final result = decoded['MessagesList'] as List<dynamic>;

    for(var item in result){
      mails.add(MailEntry(item['Subject'], removeBloatFromMail(item['Detail']), item['Name'], int.parse(item['SendDate'].toString().replaceAll('\/Date(', '').replaceAll(')\/', '')), !item['IsNew'], item['PersonMessageId'].toString()));
    }
    return mails;
  }

  static String removeBloatFromMail(String raw){
    var sanitised = raw.trim();
    sanitised = sanitised.replaceAll(RegExp(r'\.\w+\{[^}]*\}'), '');
    return sanitised.trim();
  }

  static Future<void> setMailRead(String id)async{
    if ((storage.DataCache.getIsDemoAccount() ?? false) || (storage.DataCache.getHasICSFile() ?? false)) {
      return;
    }
    // On the modern API fetching the message posts already clears the unread flag server-side.
    if (storage.DataCache.getIsModernApi()) {
      return;
    }
    try {
      final username = storage.DataCache.getUsername();
      final password = storage.DataCache.getPassword();
      final baseUrl = storage.DataCache.getInstituteUrl();
      if (username == null || password == null || baseUrl == null) {
        return;
      }
      final url = Uri.parse(baseUrl + URLs.MESSAGE_SET_READ);
      await _APIRequest.postRequest(url, '{"UserLogin":"$username","Password":"$password","MessageID":$id}');
    } catch (e) {
      debug.log("Nem siker\u00fclt olvasottnak jel\u00f6lni az \u00fczenetet: $e");
    }
  }
  static Future<String> getMailContent(String messageId, String oldDetails) async {
    if (storage.DataCache.getIsDemoAccount() ?? false) {
      return oldDetails;
    }

    if (storage.DataCache.getIsModernApi()/* ?? false*/) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        final url = Uri.parse("$baseUrl/api/Messages/$messageId/Posts?messageId=$messageId");

        String responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);

        // retry if 500 status
        if (responseRaw.contains("Hiba történt") || responseRaw.contains('"statusCode":500')) {
          await Future.delayed(const Duration(milliseconds: 200)); // Vár egy picit
          responseRaw = await _APIRequest.getRequest(url, bearerToken: token); // Újra beküldi
        }
        // ---------------------------------------------------

        final decoded = conv.json.decode(responseRaw);

        if (decoded['data'] != null && decoded['data']['posts'] != null && decoded['data']['posts'].isNotEmpty) {
          String rawHtml = decoded['data']['posts'][0]['htmlText'] ?? "";
          String cleanText = rawHtml
              .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'</p>'), '\n\n')
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&nbsp;', ' ')
              .trim();
          return cleanText;
        } else {
          return "Üres válasz érkezett a Neptuntól.\n\nSzerver válasza: $responseRaw";
        }
      } catch (e) {
        return "Hálózati hiba a letöltés során:\n$e";
      }
    }
    return oldDetails;
  }
}
  
  class Term{
    int id;
    String termName;
  
    Term(this.id, this.termName);
  }
  
  class Subject{
    bool completed;
    int credit;
    int id;
    String name;
    int grade = 0;
    int failState = 0;
  
  
    Subject(this.completed, this.credit, this.name, this.id, this.grade, this.failState);
  
    @override
    String toString() {
      return '$completed\n$credit\n$id\n$name\n$grade\n$failState';
    }
  
    Subject fillWithExisting(String existing){
      var data = existing.split('\n');
      if(data.length < 6){
        completed = false;
        credit = 0;
        id = 0;
        name = 'ERROR';
        grade = 0;
        failState = 1;
        return this;
      }
      completed = bool.parse(data[0]);
      credit = int.parse(data[1]);
      id = int.parse(data[2]);
      name = data[3];
      grade = int.parse(data[4]);
      failState = int.parse(data[5]);
      return this;
    }
  }
  
  class Institute{
    late final String Name;
    late final String URL;
    late final List<String> Fallbacks;
  
    Institute(String name, String url, [List<String>? fallbacks]){
      Name = name;
      URL = url;
      Fallbacks = fallbacks ?? const [];
    }
  
    getUrl() => Uri.parse(URL);
  }
class CalendarEntry {
  late int startEpoch;
  late int endEpoch;
  late String location;
  late String title;

  late int eventType;

  late String subjectCode;
  late String teacher;
  late String? classInstanceId;
  late String? taskId;

  bool get isExam => eventType == 1;
  bool get isTask => eventType > 1;

  CalendarEntry(String start, String end, String loc, String rawTitle, bool oldIsExam) {
    startEpoch = int.parse(start);
    startEpoch = DateTime.fromMillisecondsSinceEpoch(startEpoch)
        .subtract(Duration(hours: (Generic.isDaylightSavings(DateTime.fromMillisecondsSinceEpoch(startEpoch)) ? 2 : 1)))
        .millisecondsSinceEpoch;

    endEpoch = int.parse(end);
    endEpoch = DateTime.fromMillisecondsSinceEpoch(endEpoch)
        .subtract(Duration(hours: (Generic.isDaylightSavings(DateTime.fromMillisecondsSinceEpoch(endEpoch)) ? 2 : 1)))
        .millisecondsSinceEpoch;

    location = loc;
    classInstanceId = null;
    eventType = oldIsExam ? 1 : 0;

    final regex = RegExp(r'\]([^(]+)\(');
    final match = regex.firstMatch(rawTitle);
    if (match != null) {
      title = match.group(1)!.replaceAll(']', '').replaceAll('(', '').replaceAll('\u0009', '').trim();
    } else {
      title = rawTitle;
    }

    final regex2 = RegExp(r'\(.*?\)');
    final match2 = regex2.firstMatch(rawTitle);
    subjectCode = match2 != null ? match2.group(0)!.replaceAll('(', '').replaceAll(')', '') : "-";

    var regex3 = RegExp(r'\(.*?\)(?=\s*\(.*?\)*$)');
    var match3 = regex3.firstMatch(rawTitle);
    if (match3 != null) {
      teacher = match3.group(0)!.trim().replaceAll('(', '').replaceAll(')', '');
    } else {
      teacher = "-";
    }
  }

  // MODERN API
  CalendarEntry.fromModern({
    required this.startEpoch,
    required this.endEpoch,
    required this.location,
    required this.title,
    required this.eventType,
    required this.subjectCode,
    required this.teacher,
    this.classInstanceId,
    this.taskId,
  });

  @override
  String toString() {
    return '$startEpoch\n$endEpoch\n$location\n$title\n$eventType\n$teacher\n$subjectCode\n${classInstanceId ?? ""}\n${taskId ?? ""}';
  }

  CalendarEntry fillWithExisting(String existing) {
    var data = existing.split('\n');
    if (data.isEmpty || data.length < 7) return this;

    startEpoch = int.parse(data[0]);
    endEpoch = int.parse(data[1]);
    location = data[2];
    title = data[3];

    if (data[4] == 'true') eventType = 1;
    else if (data[4] == 'false') eventType = 0;
    else eventType = int.parse(data[4]);

    teacher = data[5];
    subjectCode = data[6];

    if (data.length >= 8 && data[7].trim().isNotEmpty) {
      classInstanceId = data[7].trim();
    } else { classInstanceId = null; }

    if (data.length >= 9 && data[8].trim().isNotEmpty) {
      taskId = data[8].trim();
    } else { taskId = null; }

    return this;
  }
}

class CashinEntry{
  late String ID;
  late int ammount;
  late int dueDateMs;
  late String comment;
  late bool completed = false;

  CashinEntry(this.ammount, this.dueDateMs, this.comment, this.ID, String completedStatus){
    if(completedStatus.toLowerCase() == 'teljesített' ||
        completedStatus.toLowerCase() == 'törölt' ||
        completedStatus.toLowerCase() == 'pénzügyileg igazolt'){
      completed = true;
    }
  }

  @override
  String toString() {
    return '$ammount\n$dueDateMs\n$comment\n$completed\n$ID';
  }

  CashinEntry fillWithExisting(String existing){
    var data = existing.split('\n');
    if(data.isEmpty || data.length < 5){
      return this;
    }
    ammount = int.parse(data[0]);
    dueDateMs = int.parse(data[1]);
    comment = data[2];
    completed = bool.parse(data[3]);
    ID = data[4];
    return this;
  }
}


  
  enum PeriodType{
    timetableRegistration,
    gradingTime,
    loginTime,
    pregivenGradingAccepting,
    timetableFinalization,
    coursesRegistration,
    nerdTime,
    examTime,
    signinTime,
    none
  }
  
  class PeriodEntry{
    late String name;
    late int startEpoch;
    late int endEpoch;
    late bool isActive;
    late int partofSemester;
    late PeriodType type;
  
    PeriodEntry(this.name, int startEpoch, int endEpoch, this.partofSemester){
      final startEp = DateTime.fromMillisecondsSinceEpoch(startEpoch);
      final correctedStartEpoch = DateTime(startEp.year, startEp.month, startEp.day);
      this.startEpoch = correctedStartEpoch.millisecondsSinceEpoch;
  
      final endEp = DateTime.fromMillisecondsSinceEpoch(endEpoch).add(const Duration(days: 1)); // last day counts too
      var correctedEndEpoch = DateTime(endEp.year, endEp.month, endEp.day);
      final isOverflowedByOneDay = endEp.add(Duration(minutes: 1)).hour == 1;
      if(isOverflowedByOneDay){
        correctedEndEpoch = correctedEndEpoch.subtract(Duration(days: 1));
      }
      this.endEpoch = correctedEndEpoch.millisecondsSinceEpoch;
  
  
      fillIsActiveStatus();
    }
  
    @override
    String toString() {
      return '$name\n$startEpoch\n$endEpoch\n$partofSemester';
    }
  
    String getValue(){
      return '$startEpoch-$endEpoch';
    }
  
    PeriodEntry fillWithExisting(String existing){
      var data = existing.split('\n');
      if(data.isEmpty || data.length < 4){
        return this;
      }
      name = data[0];
      startEpoch = int.tryParse(data[1]) ?? 0;
      endEpoch = int.parse(data[2]);
      partofSemester = int.parse(data[3]);
      fillIsActiveStatus();
      return this;
    }
  
    void fillIsActiveStatus() {
      final now = DateTime.now().millisecondsSinceEpoch;
      isActive = (startEpoch < now && now < endEpoch);
  
      switch (name.toLowerCase().trim()){
        case 'előzetes tárgyjelentkezés':
          type = PeriodType.timetableRegistration;
          break;
        case 'jegybeírási időszak':
          type = PeriodType.gradingTime;
          break;
        case 'bejelentkezési időszak':
          type = PeriodType.loginTime;
          break;
        case 'megajánlott jegy beírási időszak':
          type = PeriodType.pregivenGradingAccepting;
          break;
        case 'végleges tárgyjelentkezés':
          type = PeriodType.timetableFinalization;
          break;
        case 'kurzusjelentkezési időszak':
          type = PeriodType.coursesRegistration;
          break;
        case 'szorgalmi időszak':
          type = PeriodType.nerdTime;
          break;
        case 'vizsgajelentkezési időszak':
          type = PeriodType.examTime;
          break;
        case 'beiratkozási időszak':
          type = PeriodType.signinTime;
          break;
        default:
          type = PeriodType.none;
          break;
      }
    }
  }

  class MailEntry{
    String subject;
    String detail;
    String senderName;
    int sendDateMs;
    bool isRead;
    String ID;

    MailEntry(this.subject, this.detail, this.senderName, this.sendDateMs, this.isRead, this.ID);

    @override
    String toString() {
      return '$subject\u0000$detail\u0000$senderName\u0000$sendDateMs\u0000$isRead\u0000$ID';
    }

    MailEntry fillWithExisting(String existing){
      var data = existing.split('\u0000');
      if(data.isEmpty || data.length < 6){
        return this;
      }
      subject = data[0];
      detail = data[1];
      senderName = data[2];
      sendDateMs = int.parse(data[3]);
      isRead = bool.parse(data[4]);
      ID = data[5];
      return this;
    }
  }
  
  class Generic {
    static String reactionForAvg(double avg) {
      if (avg >= 5.0) {
        return "💀";
      }
      else if (avg >= 4.25) {
        return "🤓";
      }
      else if (avg >= 3.75) {
        return "😌";
      }
      else if (avg >= 2.75) {
        return "😐";
      }
      else if (avg >= 2) {
        return "😬";
      }
      else if (avg > 0) {
        return "🤡";
      }
      else {
        return '🤗';
      }
    }

    static String monthToText(int month) {
      switch (month) {
        case 1:
          return AppStrings.getLanguagePack().api_monthJan_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_monthFeb_Universal;
        case 3:
          return AppStrings.getLanguagePack().api_monthMar_Universal;
        case 4:
          return AppStrings.getLanguagePack().api_monthApr_Universal;
        case 5:
          return AppStrings.getLanguagePack().api_monthMay_Universal;
        case 6:
          return AppStrings.getLanguagePack().api_monthJun_Universal;
        case 7:
          return AppStrings.getLanguagePack().api_monthJul_Universal;
        case 8:
          return AppStrings.getLanguagePack().api_monthAug_Universal;
        case 9:
          return AppStrings.getLanguagePack().api_monthSep_Universal;
        case 10:
          return AppStrings.getLanguagePack().api_monthOkt_Universal;
        case 11:
          return AppStrings.getLanguagePack().api_monthNov_Universal;
        case 12:
          return AppStrings.getLanguagePack().api_monthDec_Universal;
      }
      return "NULL";
    }

    static String dayToText(int day){
      switch(day){
        case 1:
          return AppStrings.getLanguagePack().api_dayMon_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_dayTue_Universal;
        case 3:
          return AppStrings.getLanguagePack().api_dayWed_Universal;
        case 4:
          return AppStrings.getLanguagePack().api_dayThu_Universal;
        case 5:
          return AppStrings.getLanguagePack().api_dayFri_Universal;
        case 6:
          return AppStrings.getLanguagePack().api_daySat_Universal;
        case 7:
          return AppStrings.getLanguagePack().api_daySun_Universal;
        default:
          return '';
      }
    }

    static String capitalizePeriodText(String periodName) {
      final chars = periodName
          .toLowerCase()
          .trim()
          .characters
          .toList();
      String str = '';
      int idx = 0;
      bool setNexttoCapitalize = false;
      for (var item in chars) {
        if (idx == 0 || setNexttoCapitalize) {
          str += item.toUpperCase();
          idx++;
          setNexttoCapitalize = false;
          continue;
        }
        if (item == ' ') {
          setNexttoCapitalize = true;
        }
        str += item;
        idx++;
      }
      return str;
    }

    static String randomLoadingComment(bool familyFriendlyMode) {
      if (!familyFriendlyMode) {
        final gen = Random().nextInt(100) % 7;
        switch (gen) {
          case 0:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly1_Universal;
          case 1:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly2_Universal;
          case 2:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly3_Universal;
          case 3:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly4_Universal;
          case 4:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly5_Universal;
          case 5:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly6_Universal;
          case 6:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly7_Universal;
          default:
            return 'NHNK';
        }
      }
      final gen = Random().nextInt(100) % 7;
      switch (gen) {
        case 0:
          return AppStrings.getLanguagePack().api_loadingScreenHint1_Universal;
        case 1:
          return AppStrings.getLanguagePack().api_loadingScreenHint2_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_loadingScreenHint3_Universal;
        case 3:
          return AppStrings.getLanguagePack().api_loadingScreenHint4_Universal;
        case 4:
          return AppStrings.getLanguagePack().api_loadingScreenHint5_Universal;
        case 5:
          return AppStrings.getLanguagePack().api_loadingScreenHint6_Universal;
        case 6:
          return AppStrings.getLanguagePack().api_loadingScreenHint7_Universal;
        default:
          return 'NHNK';
      }
    }
    static String randomLoadingCommentMini(bool familyFriendlyMode) {
      if (!familyFriendlyMode) {
        final gen = Random().nextInt(100) % 4;
        switch (gen) {
          case 0:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini1_Universal;
          case 1:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini2_Universal;
          case 2:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini3_Universal;
          case 3:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini4_Universal;
          default:
            return 'NHNK';
        }
      }
      final gen = Random().nextInt(100) % 3;
      switch (gen) {
        case 0:
          return AppStrings.getLanguagePack().api_loadingScreenHintMini1_Universal;
        case 1:
          return AppStrings.getLanguagePack().api_loadingScreenHintMini2_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_loadingScreenHintMini3_Universal;
        default:
          return 'NHNK';
      }
    }

    static List<InlineSpan> textToInlineSpan(String text) {
      List<InlineSpan> spans = [];

      final htmlLink = RegExp(r'<a[^>]*>(.*?)</a>|https?://\S+|mailto:\S+');

      // Split the text at anchor tags using the regex pattern
      List<String> matches = htmlLink.allMatches(text)
          .map((m) => m.group(0)!)
          .toList();
      List<String> parts = text.split(htmlLink);

      for (int i = 0; i < parts.length; i++) {
        spans.add(TextSpan(text: parts[i]));
        if (i < matches.length) {
          if (matches[i].startsWith('<a')) {
            final htmlLink2 = RegExp(r'>(.*?)</a>');
            final match = htmlLink2.firstMatch(matches[i]);
            if (match == null) {
              continue;
            }
            String newText = match.group(1)!;

            if(!newText.contains('@') || !newText.contains('https://') || !newText.contains('http://')){
              final htmlLink3 = RegExp(r'href="(.*?)"');
              final match = htmlLink3.firstMatch(matches[i]);
              if (match == null) {
                break;
              }
              final url = match.group(1)!;
              spans.add(ClickableTextSpan.getNewClickableSpan(
                  ClickableTextSpan.getNewOpenLinkCallback(url), newText,
                  ClickableTextSpan.getStockStyle()));
            }
            else{
              final isMailTo = newText.contains('@') &&
                  !(newText.contains('https://') || newText.contains('http://'));

              spans.add(ClickableTextSpan.getNewClickableSpan(
                  ClickableTextSpan.getNewOpenLinkCallback(
                      isMailTo ? 'mailto:$newText' : newText.contains('www.') && !newText.contains('http:') ? 'https://$newText' : newText), newText,
                  ClickableTextSpan.getStockStyle()));
            }
          }
          else {
            // Handle URLs
            String url = matches[i];
            spans.add(ClickableTextSpan.getNewClickableSpan(
                ClickableTextSpan.getNewOpenLinkCallback(url), url,
                ClickableTextSpan.getStockStyle()));
          }
        }
      }

      return spans;
    }

    static void setupDaylightSavingsTime(){
      final now = DateTime.now();
      var probableSunday = DateTime(now.year, 3, 31, 0, 0, 0);
      if(probableSunday.weekday == 7){
        daylightSavingsTimeFrom = probableSunday;
      }
      else{
        daylightSavingsTimeFrom = probableSunday.subtract(Duration(days: probableSunday.weekday));
        if(daylightSavingsTimeFrom.hour != 0){
          daylightSavingsTimeFrom = DateTime(daylightSavingsTimeFrom.year, daylightSavingsTimeFrom.month, daylightSavingsTimeFrom.day + 1);
        }
      }

      probableSunday = DateTime(now.year, 10, 31, 0, 0, 0);
      if(probableSunday.weekday == 7){
        daylightSavingsTimeTo = probableSunday;
      }
      else{
        daylightSavingsTimeTo = probableSunday.subtract(Duration(days: probableSunday.weekday));
      }
    }

    static DateTime daylightSavingsTimeFrom = DateTime(DateTime.now().year, 3, 31, 0, 0, 0);
    static DateTime daylightSavingsTimeTo = DateTime(DateTime.now().year, 10, 27, 0, 0, 0);

    static bool isDaylightSavings(DateTime time){
      return (daylightSavingsTimeFrom.microsecondsSinceEpoch < time.microsecondsSinceEpoch && time.microsecondsSinceEpoch < daylightSavingsTimeTo.microsecondsSinceEpoch);
    }
    static Future<AppUpdateHelper?> getAppUpdateHelper() async{
      final url = Uri.parse('https://raw.githubusercontent.com/Bali0531-RC/NHNK/refs/heads/main/appMinimumAllowedVersion.json');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      Map<String, dynamic> jsonMap = conv.json.decode(response.body);
      return AppUpdateHelper(minAppVer: jsonMap["latestMinimumAllowedVerBuildNum"], minDisableVer: jsonMap["disableAppMinimumVersion"], updateUrl: jsonMap["updatePageJumper"]);
    }
  }

  class AppUpdateHelper{
    final int? minAppVer;
    final int? minDisableVer;
    final String? updateUrl;
    const AppUpdateHelper({required this.minAppVer, required this.minDisableVer, required this.updateUrl});
  }

  class Language{
    static Future<bool> checkSupportedUserLanguage()async{
      final deviceLang = AppPlatform.localeName.split('_')[0].toLowerCase();
      // check language
      final allLang = await Language.getAllLanguages();
      return Language.getHasLanguageById(allLang, deviceLang);
    }

    static bool getHasLanguageById(List<LangPackMap>? languages, String neededId){
      if(languages == null){
        return false;
      }
      for(var item in languages){
        if(item.langId == neededId){
          return true;
        }
      }
      return false;
    }

    static Future<LanguagePack?> getLanguagePackById(List<LangPackMap>? languages, String neededID)async{
      if(languages == null){
        return null;
      }
      String? langUrl;
      for(var item in languages){
        if(item.langId == neededID){
          langUrl = item.langURL;
          break;
        }
      }
      if(langUrl == null){
        return null;
      }

      final url = Uri.parse(langUrl);
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return null;
      }
      return LanguagePack.fromJson(neededID, response.body, (){}); // auto registers itself, as its downloaded, no need for the callback, def not invalid as it has just been downloaded
    }

    static List<LangPackMap>? _langMapCache;
    static List<LangPackMap> getAllLanguagesWithNative(){
      final nativeList = <LangPackMap>[
        LangPackMap(langName: 'Magyar', langId: 'hu', langURL: '', langFlag: '🇭🇺'),
        LangPackMap(langName: 'English', langId: 'en', langURL: '', langFlag: '🇺🇸/🇬🇧')];

      if(!DataCache.getHasNetwork()){
        return nativeList;
      }
      return nativeList + (_langMapCache == null ? <LangPackMap>[].toList() : _langMapCache!);
    }

    static Future<List<LangPackMap>?> getAllLanguages()async{
      if(_langMapCache != null){
        return _langMapCache;
      }
      final url = Uri.parse('https://raw.githubusercontent.com/Bali0531-RC/NHNK/refs/heads/main/Languages/supportedLanguages.json');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      Map<String, dynamic> jsonMap = conv.json.decode(response.body);
      final allLangItems = jsonMap['languagesMap'] as List<dynamic>;
      final List<LangPackMap> langPacksRoot = [];
      for (var item in allLangItems){
        langPacksRoot.add(LangPackMap.fromMap(item));
      }
      _langMapCache = langPacksRoot;
      return langPacksRoot;
    }
  }

  class LangPackMap{
    final String langName;
    final String langFlag;
    final String langId;
    final String langURL;

    const LangPackMap({required this.langName, required this.langId, required this.langURL, required this.langFlag});

    static LangPackMap fromMap(Map<String, dynamic> json){
      return LangPackMap(langName: json['langName'], langId: json['langId'], langURL: json['langURL'], langFlag: json['langFlag']);
    }
  }

  class Coloring{
    static List<ThemePackMap>? _themeMapCache;

    static List<ThemePackMap>? getAllThemesCache(){
      return _themeMapCache;
    }

    static Future<List<ThemePackMap>?> getAllThemes()async{
      if(_themeMapCache != null){
        return _themeMapCache;
      }
      final url = Uri.parse('https://raw.githubusercontent.com/Bali0531-RC/NHNK/refs/heads/main/Themes/supportedThemes.json');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      Map<String, dynamic> jsonMap = conv.json.decode(response.body);
      final allThemeItems = jsonMap['themesMap'] as List<dynamic>;
      final List<ThemePackMap> themePacksRoot = [];
      for (var item in allThemeItems){
        themePacksRoot.add(ThemePackMap.fromMap(item));
      }
      _themeMapCache = themePacksRoot;
      return themePacksRoot;
    }

    static Future<AppPalette?> getThemePackById(List<ThemePackMap>? themes, String neededID)async{
      if(themes == null){
        return null;
      }
      String? themeUrl;
      for(var item in themes){
        if(item.themeName == neededID){
          themeUrl = item.themeUrl;
          break;
        }
      }
      if(themeUrl == null){
        return null;
      }

      final url = Uri.parse(themeUrl);
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return null;
      }
      return AppPalette.fromJson(response.body, (){}); // auto registers itself, as its downloaded, no need for the callback, def not invalid as it has just been downloaded
    }
  }

  class ThemePackMap{
    final String themeName;
    final String themeUrl;
    final Color themepackAccent;

    const ThemePackMap({required this.themeName, required this.themeUrl, required this.themepackAccent});

    static ThemePackMap fromMap(Map<String, dynamic> json){
      return ThemePackMap(themeName: json['themeName'], themeUrl: json['themeURL'], themepackAccent: Color(json['themeAccent']));
    }
  }
  
  class NeptunCerts extends HttpOverrides {
    static NeptunCerts? _instance;
    static bool hasValidCertificate = true;

    static NeptunCerts getCerts(){
      if(_instance != null){
        return _instance!;
      }
      return NeptunCerts();
    }

    NeptunCerts(){
      _instance = this;
    }
    @override
    HttpClient createHttpClient(SecurityContext? context) {
      // Certificate validation is left at the platform default on purpose:
      // accepting any certificate here would expose the Neptun password to MITM.
      final client = super.createHttpClient(context);
      client.connectionTimeout = const Duration(seconds: 20);
      return client;
    }
  }
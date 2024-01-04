library mail_check;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:mail_check/ascii_folder.dart';

class MailCheckResponse {
  bool isValidEmail;
  MailCheckResult? suggestion;

  MailCheckResponse({required this.isValidEmail, this.suggestion});
}

class MailCheckResult {
  String? address;
  String? domain;
  String? fullEmail;
  SuggestionType suggestionType;

  MailCheckResult(
      {this.address,
      this.domain,
      this.fullEmail,
      this.suggestionType = SuggestionType.notFoundDomain});
}

enum SuggestionType { hasSpecialCharacter, notFoundDomain }

class MailCheck {
  static var shared = MailCheck._init();
  MailCheck._init();

  Future<void> _loadDomains() async {
    try {
      var domainStr = await rootBundle.loadString(
          'packages/mail_check/assets/all_email_provider_domains.txt');
      await _parseDomains(domainStr: domainStr);
    } catch (e) {
      debugPrint("load domains error => $e");
    }
  }

  Future<void> _parseDomains({required String domainStr}) async {
    List<String> domainList = domainStr.split('\n');
    domainFiles.addAll(domainList);
  }

  List<String> allDomains = [];
  List<String> domainFiles = [];
  static const int domainThreshold = 4;
  static const int topLevelThreshold = 3;
  static const String defaultRegex =
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';

  final List<String> defaultDomains = [
    "yahoo.com",
    "google.com",
    "hotmail.com",
    "gmail.com",
    "me.com",
    "aol.com",
    "mac.com",
    "live.com",
    "comcast.net",
    "googlemail.com",
    "msn.com",
    "hotmail.co.uk",
    "yahoo.co.uk",
    "facebook.com",
    "verizon.net",
    "sbcglobal.net",
    "att.net",
    "gmx.com",
    "mail.com",
    "outlook.com",
    "icloud.com"
  ];

  final List<String> defaultTopLevelDomains = [
    "co.jp",
    "co.uk",
    "com",
    "net",
    "org",
    "info",
    "edu",
    "gov",
    "mil",
    "ca"
  ];

  String _regex = "";

  Future<void> run(String email,
      {String? customRegex,
      List<String>? customDomains,
      List<String>? customTopLevelDomains,
      double minDistancePercent = 60.0,
      int Function(String, String)? customDistanceFunction,
      Function(MailCheckResponse)? callBack}) async {
    if (domainFiles.isEmpty) {
      await _loadDomains();
    }

    allDomains = mergeArrays(
        domainFiles, mergeArrays(defaultDomains, customDomains ?? []));
    List<String> topLevelDomains =
        mergeArrays(defaultTopLevelDomains, customTopLevelDomains ?? []);
    _regex = customRegex ?? defaultRegex;
    int Function(String, String)? distanceFunction = customDistanceFunction;

    MailCheckResponse result = suggest(
      email,
      allDomains,
      topLevelDomains,
      minDistancePercent,
      distanceFunction,
    );

    callBack?.call(result);
  }

  MailCheckResponse suggest(
    String email,
    List<String> domains,
    List<String> topLevelDomains,
    double minDistancePercent,
    int Function(String, String)? distanceFunction,
  ) {
    email = email.toLowerCase();
    // Check Email regex
    if (!isValidEmail(email)) {
      return MailCheckResponse(isValidEmail: false);
    }

    EmailParts? emailParts = splitEmail(email);
    if (emailParts == null) {
      return MailCheckResponse(isValidEmail: false);
    }

    String closestAddress = ASCIIFolder.foldMaintaining(emailParts.address);
    bool isSuggestAddress = closestAddress != emailParts.address;
    String? closestDomain = findClosestDomain(
      emailParts.domain,
      domains,
      distanceFunction,
      minDistancePercent,
      domainThreshold,
    );
    debugPrint("Closest domain => $closestDomain");
    debugPrint("emailParts domain => ${emailParts.domain}");
    if (allDomains.contains(emailParts.domain)) {
      return MailCheckResponse(isValidEmail: true);
    }

    if (closestDomain != null && closestDomain != emailParts.domain) {
      // The email address closely matches one of the supplied domains; return a suggestion
      String nonAsciiDomain = ASCIIFolder.foldMaintaining(closestDomain);
      final isContainSCharacter =
          isSuggestAddress || (nonAsciiDomain != closestDomain);
      return MailCheckResponse(
        isValidEmail: true,
        suggestion: MailCheckResult(
            address: isSuggestAddress ? closestAddress : emailParts.address,
            domain: nonAsciiDomain,
            fullEmail:
                '${isSuggestAddress ? closestAddress : emailParts.address}@$nonAsciiDomain',
            suggestionType: isContainSCharacter
                ? SuggestionType.hasSpecialCharacter
                : SuggestionType.notFoundDomain),
      );
    } else {
      // The email address does not closely match one of the supplied domains
      String? closestTopLevelDomain = findClosestDomain(
        emailParts.topLevelDomain,
        topLevelDomains,
        distanceFunction,
        minDistancePercent,
        topLevelThreshold,
      );
      debugPrint("closestTopLevelDomain => $closestTopLevelDomain");
      debugPrint("email closestTopLevelDomain => ${emailParts.topLevelDomain}");
      if (closestTopLevelDomain != null &&
          closestTopLevelDomain != emailParts.topLevelDomain) {
        // The email address may have a misspelled top-level domain; return a suggestion
        String domain = emailParts.domain;
        closestDomain =
            domain.substring(0, domain.lastIndexOf(emailParts.topLevelDomain)) +
                closestTopLevelDomain;
        String nonAsciiDomain = ASCIIFolder.foldMaintaining(closestDomain);
        final isContainSCharacter =
            isSuggestAddress || (nonAsciiDomain != closestDomain);
        return MailCheckResponse(
          isValidEmail: true,
          suggestion: MailCheckResult(
              address: isSuggestAddress ? closestAddress : emailParts.address,
              domain: nonAsciiDomain,
              fullEmail:
                  '${isSuggestAddress ? closestAddress : emailParts.address}@$nonAsciiDomain',
              suggestionType: isContainSCharacter
                  ? SuggestionType.hasSpecialCharacter
                  : SuggestionType.notFoundDomain),
        );
      } else {
        String nonAsciiDomain = ASCIIFolder.foldMaintaining(emailParts.domain);
        final isContainSCharacter =
            isSuggestAddress || (nonAsciiDomain != emailParts.domain);
        if (isContainSCharacter) {
          return MailCheckResponse(
            isValidEmail: true,
            suggestion: MailCheckResult(
                address: closestAddress,
                domain: nonAsciiDomain,
                fullEmail: '$closestAddress@$nonAsciiDomain',
                suggestionType: isContainSCharacter
                    ? SuggestionType.hasSpecialCharacter
                    : SuggestionType.notFoundDomain),
          );
        }
      }
    }
    // The email address exactly matches one of the supplied domains, does not closely
    // match any domain, and does not appear to simply have a misspelled top-level domain,
    // or it is an invalid email address; do not return a suggestion.
    return MailCheckResponse(isValidEmail: true);
  }

  String? findClosestDomain(
    String domain,
    List<String> domains,
    int Function(String, String)? distanceFunction,
    double minDistancePercent,
    int threshold,
  ) {
    threshold = threshold;

    double dist;
    double minDist = minDistancePercent;

    String? closestDomain;
    if (domain.isEmpty || domains.isEmpty) {
      return null;
    }

    distanceFunction ??= sift3Distance;
    for (int i = 0; i < domains.length; i++) {
      if (domain == domains[i]) {
        return domain;
      }

      dist = calculateDistancePercent(domain, domains[i]);
      if (dist >= minDist) {
        minDist = dist;
        closestDomain = domains[i];
      }
    }

    return closestDomain;
  }

  int sift3Distance(String s1, String s2) {
    if (s1.isEmpty) {
      if (s2.isEmpty) {
        return 0;
      } else {
        return s2.length;
      }
    }

    if (s2.isEmpty) {
      return s1.length;
    }

    int c = 0;
    int offset1 = 0;
    int offset2 = 0;
    int lcs = 0;
    int maxOffset = 5;

    while ((c + offset1 < s1.length) && (c + offset2 < s2.length)) {
      if (s1[c + offset1] == s2[c + offset2]) {
        lcs++;
      } else {
        offset1 = 0;
        offset2 = 0;
        for (int i = 0; i < maxOffset; i++) {
          if ((c + i < s1.length) && (s1[c + i] == s2[c])) {
            offset1 = i;
            break;
          }
          if ((c + i < s2.length) && (s1[c] == s2[c + i])) {
            offset2 = i;
            break;
          }
        }
      }
      c++;
    }
    return (s1.length + s2.length) ~/ 2 - lcs;
  }

  double calculateDistancePercent(String s1, String s2) {
    int calculateLevenshteinDistance(String a, String b) {
      final int m = a.length, n = b.length;
      List<List<int>> dp =
          List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

      for (int i = 1; i <= m; i++) {
        dp[i][0] = i;
      }

      for (int j = 1; j <= n; j++) {
        dp[0][j] = j;
      }

      for (int i = 1; i <= m; i++) {
        for (int j = 1; j <= n; j++) {
          int cost = a[i - 1] == b[j - 1] ? 0 : 1;
          dp[i][j] = <int>[
            dp[i - 1][j] + 1,
            dp[i][j - 1] + 1,
            dp[i - 1][j - 1] + cost
          ].reduce((int min, int element) => element < min ? element : min);
        }
      }

      return dp[m][n];
    }

    int distance = calculateLevenshteinDistance(s1, s2);
    int maxLength = s1.length > s2.length ? s1.length : s2.length;
    double distancePercent = ((maxLength - distance) / maxLength) * 100;
    return distancePercent;
  }

  EmailParts? splitEmail(String email) {
    List<String> parts = email.trim().split('@');

    if (parts.length < 2) {
      return null;
    }

    for (String part in parts) {
      if (part.isEmpty) {
        return null;
      }
    }

    String domain = parts.removeLast();
    List<String> domainParts = domain.split('.');
    String tld = '';

    if (domainParts.isEmpty) {
      // The address does not have a top-level domain
      return null;
    } else if (domainParts.length == 1) {
      // The address has only a top-level domain (valid under RFC)
      tld = domainParts[0];
    } else {
      // The address has a domain and a top-level domain
      for (int i = 1; i < domainParts.length; i++) {
        tld += '${domainParts[i]}.';
      }
      if (domainParts.length >= 2) {
        tld = tld.substring(0, tld.length - 1);
      }
    }

    return EmailParts(
      topLevelDomain: tld,
      domain: domain,
      address: parts.join('@'),
    );
  }

  String encodeEmail(String email) {
    String result = Uri.encodeComponent(email);
    result = result
        .replaceAll('%20', ' ')
        .replaceAll('%25', '%')
        .replaceAll('%5E', '^')
        .replaceAll('%60', '`')
        .replaceAll('%7B', '{')
        .replaceAll('%7C', '|')
        .replaceAll('%7D', '}')
        .replaceAll('%40', '@');
    return result;
  }

  List<String> mergeArrays(List<String> array1, List<String> array2) {
    Set<String> mergedSet = Set<String>.from(array1)..addAll(array2);

    return mergedSet.toList();
  }

  bool isValidEmail(String email) {
    return RegExp(_regex).hasMatch(email);
  }
}

class EmailParts {
  String topLevelDomain;
  String domain;
  String address;

  EmailParts({
    required this.topLevelDomain,
    required this.domain,
    required this.address,
  });
}

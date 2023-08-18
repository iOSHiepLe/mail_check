library mail_check;

import 'package:flutter/cupertino.dart';
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
  static const int domainThreshold = 4;
  static const int topLevelThreshold = 3;
  static const String defaultRegex =
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';

  static final List<String> defaultDomains = [
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

  static final List<String> defaultTopLevelDomains = [
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

  static String _regex = "";

  static void run(String email,
      {String? customRegex,
      List<String>? customDomains,
      List<String>? customTopLevelDomains,
      int Function(String, String)? customDistanceFunction,
      Function(MailCheckResponse)? callBack}) {
    List<String> domains = mergeArrays(defaultDomains, customDomains ?? []);
    List<String> topLevelDomains =
        mergeArrays(defaultTopLevelDomains, customTopLevelDomains ?? []);
    _regex = customRegex ?? defaultRegex;
    int Function(String, String)? distanceFunction = customDistanceFunction;

    MailCheckResponse result = suggest(
      email,
      domains,
      topLevelDomains,
      distanceFunction,
    );

    callBack?.call(result);
  }

  static MailCheckResponse suggest(
    String email,
    List<String> domains,
    List<String> topLevelDomains,
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
      domainThreshold,
    );

    if (closestDomain != null && closestDomain != emailParts.domain) {
      // The email address closely matches one of the supplied domains; return a suggestion
      debugPrint("Test => 000");
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
      debugPrint("Test => 111");
      // The email address does not closely match one of the supplied domains
      String? closestTopLevelDomain = findClosestDomain(
        emailParts.topLevelDomain,
        topLevelDomains,
        distanceFunction,
        topLevelThreshold,
      );

      if (closestTopLevelDomain != null &&
          closestTopLevelDomain != emailParts.topLevelDomain) {
        debugPrint("Test => 222");
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
        debugPrint("Test => 333");
        String nonAsciiDomain = ASCIIFolder.foldMaintaining(emailParts.domain);
        final isContainSCharacter =
            isSuggestAddress || (nonAsciiDomain != emailParts.domain);
        debugPrint(
            "Test => 333 => closestDomain: $closestDomain - nonAsciiDomain: $nonAsciiDomain");
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

  static String? findClosestDomain(
    String domain,
    List<String> domains,
    int Function(String, String)? distanceFunction,
    int threshold,
  ) {
    threshold = threshold;

    int dist;
    int minDist = 99;
    String? closestDomain;

    if (domain.isEmpty || domains.isEmpty) {
      return null;
    }

    distanceFunction ??= sift3Distance;

    for (int i = 0; i < domains.length; i++) {
      if (domain == domains[i]) {
        return domain;
      }
      dist = distanceFunction(domain, domains[i]);
      if (dist < minDist) {
        minDist = dist;
        closestDomain = domains[i];
      }
    }

    if (minDist <= threshold && closestDomain != null) {
      return closestDomain;
    } else {
      return null;
    }
  }

  static int sift3Distance(String s1, String s2) {
    // Sift3: http://siderite.blogspot.com/2007/04/super-fast-and-accurate-string-distance.html
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

  static EmailParts? splitEmail(String email) {
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

  static String encodeEmail(String email) {
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

  static List<String> mergeArrays(List<String> array1, List<String> array2) {
    Set<String> mergedSet = Set<String>.from(array1)..addAll(array2);

    return mergedSet.toList();
  }

  static bool isValidEmail(String email) {
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

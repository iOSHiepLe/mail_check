# mail_check

A Flutter package for both android, iOS and Web. which provides validate email and make suggestion.

## Screenshots

<img src="https://github.com/iOSHiepLe/mail_check/blob/main/mail_check/screenshots/email_suggestion.png" height="400em" width="225em" />

## Usage

[Example](https://github.com/iOSHiepLe/mail_check/blob/main/mail_check/example/lib/main.dart)

To use this package :

* add the dependency to your [pubspec.yaml](https://github.com/parth58/Social-SignIn-Buttons/blob/master/pubspec.yaml) file.

```yaml
  dependencies:
    flutter:
      sdk: flutter
    mail_check:
```

### How to use

```dart
void _checkEmail() {
  var email = controller.value.text;
  MailCheck.run(email, callBack: (response) {
    var message = "$email is a valid email";
    if (response.isValidEmail) {
      if (response.suggestion != null) {
        message =
        "Are you sure with email: $email\nSuggestion: ${response.suggestion?.fullEmail}";
      }
    } else {
      message = "$email is an invalid email";
    }
    setState(() {
      _message = message;
    });
  });
}

```

### List Of Support Domains default
* yahoo.com
* google.com
* hotmail.com
* gmail.com
* me.com
* aol.com
* mac.com
* live.com
* comcast.net
* googlemail.com
* msn.com
* hotmail.co.uk
* yahoo.co.uk
* facebook.com
* verizon.net
* sbcglobal.net
* att.net
* mx.com
* ail.com
* utlook.com
* cloud.com

# License
Copyright (c) 2023 HiepLe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


## Getting Started

For help getting started with Flutter, view our online [documentation](https://flutter.io/).

For help on editing package code, view the [documentation](https://flutter.io/developing-packages/).

// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

part of '../../pay.dart';

/// A widget that handles the API logic to facilitate the integration.
///
/// This widget provides an alternative UI-based integration path that wraps
/// the API calls of the payment libraries and includes them as part of the
/// lifecycle of the widget. As a result of that:
///
/// 1. The widget only shows if the [Pay.userCanPay] method returns `true`, or
/// displays the [childOnError] widget and calls the [onError] function
/// otherwise.
/// 2. Tapping the button automatically triggers the [Pay.showPaymentSelector]
/// method which starts the payment process.
abstract class PayButton extends StatefulWidget {
  /// A resident client to issue requests against the APIs.
  late final Pay _payClient;

  /// Specifies the payment provider supported by the button
  final PayProvider buttonProvider;

  /// A function called when the payment process yields a result.
  final void Function(Map<String, dynamic> result)? onPaymentResult;

  final double width;
  final double height;
  final EdgeInsets margin;

  /// A function called when there's an error in the payment process.
  final void Function(Object? error)? onError;

  /// A replacement widget shown instead of the button when the payment process
  /// errors. This can be used to show a different checkout button or an error
  /// message.
  final Widget? childOnError;

  /// An optional widget to show while the payment provider checks whether
  /// a user can pay with it and the button loads.
  final Widget? loadingIndicator;

  /// Initializes the button and the payment client that handles the requests.
  PayButton({
    super.key,
    required this.buttonProvider,
    required final PaymentConfiguration paymentConfiguration,
    this.onPaymentResult,
    this.width = 0,
    this.height = 0,
    this.margin = const EdgeInsets.all(0),
    this.onError,
    this.childOnError,
    this.loadingIndicator,
  }) : _payClient = Pay({buttonProvider: paymentConfiguration});

  /// Callback function to respond to tap events.
  ///
  /// This is the default function for tap events. Calls the [onPressed]
  /// function if set, and initiates the payment process with the [paymentItems]
  /// specified.
  VoidCallback _defaultOnPressed(
      VoidCallback? onPressed, List<PaymentItem> paymentItems) {
    return () async {
      onPressed?.call();
      try {
        final result =
            await _payClient.showPaymentSelector(buttonProvider, paymentItems);
        onPaymentResult?.call(result);
      } catch (error) {
        onError?.call(error);
      }
    };
  }

  /// Determines the list of supported platforms for the button.
  List<TargetPlatform> get _supportedPlatforms;

  /// Accessor for the widget to show as the payment button.
  ///
  /// This method returns a [Widget] that is conditionally shown based on the
  /// result of the `isReadyToPay` request.
  Widget get _payButton;

  /// Determines whether the current platform is supported by the button.
  bool get _isPlatformSupported =>
      _supportedPlatforms.contains(defaultTargetPlatform);

  @override
  State<PayButton> createState() => _PayButtonState();
}

/// Button state that adds the widgets to the tree and holds the result of the
/// `userCanPay` request.
///
/// This state executes the logic that shows the [loadingIndicator] while the
/// button loads. If the payment provider is available for a given user, the
/// [_payButton] is added to the tree. Otherwise, if set, the replacement widget
/// in [childOnError] is shown.
class _PayButtonState extends State<PayButton> with WidgetsBindingObserver {
  bool _userCan = false;

  Future<void> userCanPay() async {
    try {
      _userCan = await widget._payClient.userCanPay(widget.buttonProvider);
      if(mounted) {
        setState(() {});
      }
    } catch (error) {
      widget.onError?.call(error);
      rethrow;
    }
  }

  Future<dynamic> openPaymentSetup() async {
    try {
      var a = await widget._payClient.openPaymentSetup(widget.buttonProvider);
      return a;
    } catch (error) {
      widget.onError?.call(error);
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    userCanPay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if(state == AppLifecycleState.resumed) {
      userCanPay();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._isPlatformSupported) {
      return const SizedBox.shrink();
    }

    // Future builder running the `userCanPayFuture` and decides what to show
    // based on the result.
    return _userCan ?
      Container(
        margin: widget.margin,
        width: widget.width,
        height: widget.height,
        child: widget._payButton,
      ) : Container(
        margin: widget.margin,
        width: widget.width,
        height: widget.height,
        child: RawApplePayButton(
          style: ApplePayButtonStyle.black,
          type: ApplePayButtonType.setUp,
          onPressed: () { openPaymentSetup(); },),
      );
  }
}

/// Shows the appropriate widget based on the API requests above, respecting the
/// [margin] if the [child] is set.
class ButtonPlaceholder extends StatelessWidget {
  final Widget? child;
  final EdgeInsets margin;

  const ButtonPlaceholder({
    super.key,
    this.child,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return child == null
        ? const SizedBox.shrink()
        : Container(margin: margin, child: child);
  }
}

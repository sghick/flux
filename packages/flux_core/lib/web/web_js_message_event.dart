class WebJsMessageEvent {
  final String? method;
  final Map<String, dynamic>? args;
  final String? callback;

  WebJsMessageEvent({
    required this.method,
    required this.args,
    required this.callback,
  });

  factory WebJsMessageEvent.fromJson(Map<String, dynamic> json) {
    return WebJsMessageEvent(
      method: json['method'],
      args: json['args'],
      callback: json['callback'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'args': args,
      'callback': callback,
    };
  }
}

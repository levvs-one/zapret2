/// How a service is unblocked.
enum Mechanism {
  /// Traffic goes directly to the service, zapret2 desynchronizes DPI.
  dpi,

  /// The service refuses Russian users. Its domains are resolved through a
  /// smart DNS that routes them via a foreign gateway.
  smartDns,

  /// Telegram Desktop connects to a local MTProto proxy that tunnels it
  /// through Telegram's own WebSocket endpoints.
  telegram,
}

class Service {
  const Service({
    required this.id,
    required this.title,
    required this.caption,
    required this.mechanism,
    this.domains = const [],
  });

  final String id;
  final String title;
  final String caption;
  final Mechanism mechanism;

  /// Domains the mechanism applies to. Subdomains are always included.
  final List<String> domains;
}

abstract final class Catalog {
  static const youtube = Service(
    id: 'youtube',
    title: 'YouTube',
    caption: 'Видео в полном качестве',
    mechanism: Mechanism.dpi,
  );

  static const discord = Service(
    id: 'discord',
    title: 'Discord',
    caption: 'Голос и демонстрация экрана',
    mechanism: Mechanism.dpi,
  );

  static const telegram = Service(
    id: 'telegram',
    title: 'Telegram',
    caption: 'Медиа и файлы в Telegram Desktop',
    mechanism: Mechanism.telegram,
  );

  static const gemini = Service(
    id: 'gemini',
    title: 'Gemini и AI Studio',
    caption: 'NotebookLM, Antigravity',
    mechanism: Mechanism.smartDns,
    domains: [
      'gemini.google.com',
      'aistudio.google.com',
      'ai.google.dev',
      'notebooklm.google.com',
      'notebooklm.google',
      'labs.google',
      'antigravity.google',
      'generativelanguage.googleapis.com',
      'alkalimakersuite-pa.clients6.google.com',
      'cloudcode-pa.googleapis.com',
      'daily-cloudcode-pa.googleapis.com',
      'geminicodeassist.googleapis.com',
    ],
  );

  static const chatgpt = Service(
    id: 'chatgpt',
    title: 'ChatGPT',
    caption: 'OpenAI, Sora, Codex',
    mechanism: Mechanism.smartDns,
    domains: [
      'chatgpt.com',
      'openai.com',
      'oaistatic.com',
      'oaiusercontent.com',
      'sora.com',
    ],
  );

  static const claude = Service(
    id: 'claude',
    title: 'Claude',
    caption: 'Anthropic',
    mechanism: Mechanism.smartDns,
    domains: ['claude.ai', 'anthropic.com', 'claude.com'],
  );

  static const copilot = Service(
    id: 'copilot',
    title: 'Copilot',
    caption: 'Microsoft и GitHub',
    mechanism: Mechanism.smartDns,
    domains: [
      'copilot.microsoft.com',
      'githubcopilot.com',
      'copilot-proxy.githubusercontent.com',
    ],
  );

  static const spotify = Service(
    id: 'spotify',
    title: 'Spotify',
    caption: 'Музыка и подкасты',
    mechanism: Mechanism.smartDns,
    domains: ['spotify.com', 'scdn.co', 'spotifycdn.com'],
  );

  static const all = [
    youtube,
    discord,
    telegram,
    gemini,
    chatgpt,
    claude,
    copilot,
    spotify,
  ];

  static Service byId(String id) => all.firstWhere((s) => s.id == id);
}

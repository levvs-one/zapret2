/// A smart DNS that answers with a foreign gateway for geo-restricted
/// services and with real addresses for everything else.
class SmartDnsProvider {
  const SmartDnsProvider({
    required this.id,
    required this.title,
    required this.website,
    required this.servers,
  });

  final String id;
  final String title;
  final String website;
  final List<String> servers;

  static const xboxDns = SmartDnsProvider(
    id: 'xbox-dns',
    title: 'Xbox DNS',
    website: 'https://xbox-dns.ru',
    servers: ['111.88.96.54', '111.88.96.55'],
  );

  static const all = [xboxDns];

  static SmartDnsProvider byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => xboxDns);
}

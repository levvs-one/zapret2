/// TLS strategies rotated by `prosvet_circular` for a host that is being
/// blocked. Order matters: the most compatible and cheapest go first.
///
/// Every entry is a list of zapret2 `--lua-desync` values for one strategy.
/// Strategy numbers are assigned by position.
const tlsStrategies = <List<String>>[
  [
    'fake:blob=fake_default_tls:tcp_md5:repeats=2',
    'multidisorder:pos=1,midsld',
  ],
  [
    'fake:blob=fake_default_tls:tcp_md5:tls_mod=rnd,dupsid,sni=www.google.com:repeats=2',
    'multisplit:pos=1,midsld',
  ],
  ['multisplit:pos=1:seqovl=681:seqovl_pattern=fake_default_tls'],
  ['hostfakesplit:host=www.google.com:tcp_md5:midhost=midsld'],
  ['fakedsplit:pos=midsld:tcp_md5'],
  [
    'fake:blob=fake_default_tls:tcp_seq=-10000:repeats=4',
    'multidisorder:pos=1,host+2,midsld',
  ],
];

/// Bumped whenever [tlsStrategies] changes, so remembered strategy numbers
/// from an older catalog are never applied to a different strategy.
const strategyCatalogVersion = 1;

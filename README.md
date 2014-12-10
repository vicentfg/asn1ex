ASN1ex
======

ASN.1 compiler mix task to generate erlang parser using asn1rt and asn1ct.

## Configuration

Add the line the following line on the project function of mix.exs file:

- `compilers: Mix.compilers ++ [:asn1]`

Other configuration options:

- `:asn1_paths` - directories to find source files. Defaults to `["asn1"]`.

- `:erlc_paths` - directories to store generated source files. Defaults to
  `["src"]`.

- `:asn1_options` - compilation options that apply to ASN.1's compiler. There
  are many other available options here:
  http://erlang.org/doc/man/asn1ct.html#compile-2.

# Fixing OpenSSL CRL Certificate Verification Issues

## The Problem

OpenSSL 3.6.0 has stricter CRL (Certificate Revocation List) verification which causes SSL errors when fetching HTTPS URLs in Ruby:

```
SSL_connect returned=1 errno=0 state=error: certificate verify failed (unable to get certificate CRL)
```

## Solution (Implemented)

Add the `openssl` gem explicitly to your Gemfile:

```bash
bundle add openssl
```

This uses the Ruby openssl gem (version 3.3.1) which handles OpenSSL 3.6.0 compatibility better than the stdlib version.

## References

- https://github.com/rails/rails/issues/55886
- https://github.com/rbenv/ruby-build/discussions/2264
- https://github.com/Homebrew/homebrew-core/issues/153074

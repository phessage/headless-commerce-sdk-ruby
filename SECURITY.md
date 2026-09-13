# Security policy

## Reporting a vulnerability

Report security issues privately through GitHub: open this repository's **Security** tab and choose **Report a vulnerability**. Please do not open a public issue for a security problem.

Include what you found, how to reproduce it, and what someone could do with it. We acknowledge reports and keep you informed while we fix them.

## Scope

In scope: the code in this repository, and how it uses the 1Ecomm headless commerce API.

The 1Ecomm platform at `api.1ecomm.com` is also in scope when the finding came from using this project. Do not run automated scanners, load tests or denial-of-service tests against production, and do not access data that is not yours.

## What is not a vulnerability

- **A store ID or publishable key in this repository or in a browser.** Both are public by design. A publishable key identifies one store and grants only its public storefront scopes, never administrative access.
- **The default store ID in the configuration.** It points to a public demo store that cannot place orders.
- **Rate limiting (HTTP 429).** It is expected when a client exceeds the store's request policy.

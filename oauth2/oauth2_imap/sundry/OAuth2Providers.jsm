/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Details of supported OAuth2 Providers.
 */
var EXPORTED_SYMBOLS = ["OAuth2Providers"];

// When we add a Google mail account, ask for address book and calendar scopes
// as well. Then we can add an address book or calendar without asking again.
//
// Don't ask for all the scopes when adding an address book or calendar
// independently of the mail set-up process. If a mail account already exists,
// we already have a token, and if it doesn't the user is likely to be setting
// up an address book/calendar without wanting mail.
const GOOGLE_SCOPES =
  "https://mail.google.com/ https://www.googleapis.com/auth/carddav https://www.googleapis.com/auth/calendar";
const FASTMAIL_SCOPES =
  "https://www.fastmail.com/dev/protocol-imap https://www.fastmail.com/dev/protocol-pop https://www.fastmail.com/dev/protocol-smtp https://www.fastmail.com/dev/protocol-carddav https://www.fastmail.com/dev/protocol-caldav";
const COMCAST_SCOPES = "https://email.comcast.net/ profile openid";

/**
 * Map of hostnames to [issuer, scope].
 */
var kHostnames = new Map([
  ["imap.googlemail.com", ["accounts.google.com", GOOGLE_SCOPES]],
  ["smtp.googlemail.com", ["accounts.google.com", GOOGLE_SCOPES]],
  ["pop.googlemail.com", ["accounts.google.com", GOOGLE_SCOPES]],
  ["imap.gmail.com", ["accounts.google.com", GOOGLE_SCOPES]],
  ["smtp.gmail.com", ["accounts.google.com", GOOGLE_SCOPES]],
  ["pop.gmail.com", ["accounts.google.com", GOOGLE_SCOPES]],
  [
    "www.googleapis.com",
    ["accounts.google.com", "https://www.googleapis.com/auth/carddav"],
  ],

  ["imap.mail.ru", ["o2.mail.ru", "mail.imap"]],
  ["smtp.mail.ru", ["o2.mail.ru", "mail.imap"]],

  ["imap.yandex.com", ["oauth.yandex.com", "mail:imap_full"]],
  ["smtp.yandex.com", ["oauth.yandex.com", "mail:smtp"]],

  ["imap.mail.yahoo.com", ["login.yahoo.com", "mail-w"]],
  ["pop.mail.yahoo.com", ["login.yahoo.com", "mail-w"]],
  ["smtp.mail.yahoo.com", ["login.yahoo.com", "mail-w"]],

  ["imap.aol.com", ["login.aol.com", "mail-w"]],
  ["pop.aol.com", ["login.aol.com", "mail-w"]],
  ["smtp.aol.com", ["login.aol.com", "mail-w"]],

  [
    "outlook.office365.com",
    [
      "login.microsoftonline.com",
      "https://outlook.office.com/IMAP.AccessAsUser.All https://outlook.office.com/POP.AccessAsUser.All https://outlook.office.com/SMTP.Send offline_access",
    ],
  ],
  [
    "smtp.office365.com",
    [
      "login.microsoftonline.com",
      "https://outlook.office.com/IMAP.AccessAsUser.All https://outlook.office.com/POP.AccessAsUser.All https://outlook.office.com/SMTP.Send offline_access",
    ],
  ],

  ["imap.fastmail.com", ["www.fastmail.com", FASTMAIL_SCOPES]],
  ["pop.fastmail.com", ["www.fastmail.com", FASTMAIL_SCOPES]],
  ["smtp.fastmail.com", ["www.fastmail.com", FASTMAIL_SCOPES]],
  [
    "carddav.fastmail.com",
    ["www.fastmail.com", "https://www.fastmail.com/dev/protocol-carddav"],
  ],

  ["imap.comcast.net", ["comcast.net", COMCAST_SCOPES]],
  ["pop.comcast.net", ["comcast.net", COMCAST_SCOPES]],
  ["smtp.comcast.net", ["comcast.net", COMCAST_SCOPES]],

  // For testing purposes.
  ["mochi.test", ["mochi.test", "test_scope"]],
]);

/**
 * Map of issuers to clientId, clientSecret, authorizationEndpoint, tokenEndpoint,
 *  and usePKCE (RFC7636).
 * Issuer is a unique string for the organization that a Thunderbird account
 * was registered at.
 *
 * For the moment these details are hard-coded, since dynamic client
 * registration is not yet supported. Don't copy these values for your
 * own application - register one for yourself! This code (and possibly even the
 * registration itself) will disappear when this is switched to dynamic
 * client registration.
 */
var kIssuers = new Map([
  [
    "accounts.google.com",
    {
      clientId:
        "406964657835-aq8lmia8j95dhl1a2bvharmfk3t1hgqj.apps.googleusercontent.com",
      clientSecret: "kSmqreRr0qwBWJgbf5Y-PjSU",
      authorizationEndpoint: "https://accounts.google.com/o/oauth2/auth",
      tokenEndpoint: "https://www.googleapis.com/oauth2/v3/token",
    },
  ],
  [
    "o2.mail.ru",
    {
      clientId: "thunderbird",
      clientSecret: "I0dCAXrcaNFujaaY",
      authorizationEndpoint: "https://o2.mail.ru/login",
      tokenEndpoint: "https://o2.mail.ru/token",
    },
  ],
  [
    "oauth.yandex.com",
    {
      clientId: "2a00bba7374047a6ab79666485ffce31",
      clientSecret: "3ded85b4ec574c2187a55dc49d361280",
      authorizationEndpoint: "https://oauth.yandex.com/authorize",
      tokenEndpoint: "https://oauth.yandex.com/token",
    },
  ],
  [
    "login.yahoo.com",
    {
      clientId:
        "dj0yJmk9NUtCTWFMNVpTaVJmJmQ9WVdrOVJ6UjVTa2xJTXpRbWNHbzlNQS0tJnM9Y29uc3VtZXJzZWNyZXQmeD0yYw--",
      clientSecret: "f2de6a30ae123cdbc258c15e0812799010d589cc",
      authorizationEndpoint: "https://api.login.yahoo.com/oauth2/request_auth",
      tokenEndpoint: "https://api.login.yahoo.com/oauth2/get_token",
    },
  ],
  [
    "login.aol.com",
    {
      clientId:
        "dj0yJmk9OXRHc1FqZHRQYzVvJmQ9WVdrOU1UQnJOR0pvTjJrbWNHbzlNQS0tJnM9Y29uc3VtZXJzZWNyZXQmeD02NQ--",
      clientSecret: "79c1c11991d148ddd02a919000d69879942fc278",
      authorizationEndpoint: "https://api.login.aol.com/oauth2/request_auth",
      tokenEndpoint: "https://api.login.aol.com/oauth2/get_token",
    },
  ],

  [
    "login.microsoftonline.com",
    {
      clientId: "9e5f94bc-e8a4-4e73-b8be-63364c29d753", // Application (client) ID
      // https://docs.microsoft.com/en-us/azure/active-directory/develop/active-directory-v2-protocols#endpoints
      authorizationEndpoint:
        "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
      tokenEndpoint:
        "https://login.microsoftonline.com/common/oauth2/v2.0/token",
      redirectionEndpoint: "https://localhost",
    },
  ],

  [
    "www.fastmail.com",
    {
      clientId: "35f141ae",
      authorizationEndpoint: "https://api.fastmail.com/oauth/authorize",
      tokenEndpoint: "https://api.fastmail.com/oauth/refresh",
      usePKCE: true,
    },
  ],

  [
    "comcast.net",
    {
      clientId: "thunderbird-oauth",
      clientSecret: "fc5d0a314549bb3d059e0cec751fa4bd40a9cc7b",
      authorizationEndpoint: "https://oauth.xfinity.com/oauth/authorize",
      tokenEndpoint: "https://oauth.xfinity.com/oauth/token",
      usePKCE: true,
    },
  ],

  // For testing purposes.
  [
    "mochi.test",
    {
      clientId: "test_client_id",
      clientSecret: "test_secret",
      authorizationEndpoint:
        "http://mochi.test:8888/browser/comm/mail/components/addrbook/test/browser/data/redirect_auto.sjs",
      tokenEndpoint:
        "http://mochi.test:8888/browser/comm/mail/components/addrbook/test/browser/data/token.sjs",
      // I don't know why, but tests refuse to work with a plain HTTP endpoint
      // (the request is redirected to HTTPS, which we're not listening to).
      // Just use an HTTPS endpoint.
      redirectionEndpoint: "https://localhost",
    },
  ],
]);

/**
 * OAuth2Providers: Methods to lookup OAuth2 parameters for supported OAuth2
 * providers.
 */
var OAuth2Providers = {
  /**
   * Map a hostname to the relevant issuer and scope.
   *
   * @param {string} hostname - The hostname of the server. For example
   *  "imap.googlemail.com".
   *
   * @returns {Array} An array containing [issuer, scope] for the hostname, or
   *   undefined if not found.
   *   - issuer is a string representing the organization
   *   - scope is an OAuth2 parameter describing the required access level
   */
  getHostnameDetails(hostname) {
    // During CardDAV SRV autodiscovery, rfc6764#section-6 says:
    //
    // *  The client will need to make authenticated HTTP requests to
    //    the service.  Typically, a "user identifier" is required for
    //    some form of user/password authentication.  When a user
    //    identifier is required, clients MUST first use the "mailbox"
    //
    // However macOS Contacts does not do this and just uses the "localpart"
    // instead. To work around this bug, during SRV autodiscovery Fastmail
    // returns SRV records of the form '0 1 443 d[0-9]+.carddav.fastmail.com.'
    // which encodes the internal domainid of the queried SRV domain in the
    // sub-domain of the Target (rfc2782) of the SRV result. This can
    // then be extracted from the Host header on each DAV request, the
    // original domain looked up and attached to the "localpart" to create
    // a full "mailbox", allowing autodiscovery to just work for usernames
    // in any domain including self hosted domains.
    //
+
-    // So for this hostname -> issuer/scope lookup to work, we need to
    // look not just at the hostname, but also any sub-domains of this
    // hostname.
    while (hostname.includes(".")) {
      const foundHost = kHostnames.get(hostname);
      if (foundHost) {
        return foundHost;
      }
      hostname = hostname.replace(/^[^.]*[.]/, "");
    }
    return undefined;
  },

  /**
   * Map an issuer to OAuth2 account details.
   *
   * @param {string} issuer - The organization issuing OAuth2 parameters, e.g.
   *   "accounts.google.com".
   *
   * @returns {Array} An array containing [clientId, clientSecret, authorizationEndpoint, tokenEndpoint].
   *   clientId and clientSecret are strings representing the account registered
   *   for Thunderbird with the organization.
   *   authorizationEndpoint and tokenEndpoint are url strings representing
   *   endpoints to access OAuth2 authentication.
   */
  getIssuerDetails(issuer) {
    return kIssuers.get(issuer);
  },
};


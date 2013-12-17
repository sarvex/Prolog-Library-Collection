:- module(
  http_url,
  [
    http_URL//5 % -Tree:compound
                % ?Host:list(atomic)
                % ?Port:integer
                % ?Path:list(list(atom))
                % ?Query:atom
  ]
).

/** <module> HTTP URL

Grammar for HTTP URLs.

# RFC 2616

As far as HTTP is concerned, Uniform Resource Identifiers are simply
 formatted strings which identify --via name, location,
 or any other characteristic-- a resource.

## Synonyms

  * WWW addresse
  * Universal Document Identifier
  * Universal Resource Identifier (URI)
  * Uniform Resource Locator (URL) + Uniform Resource Name (URN)

## Syntax

URIs in HTTP can be represented in absolute form or relative to
 some known base URI, depending upon the context of their use.
The two forms are differentiated by the fact that absolute URIs
 always begin with a scheme name followed by a colon.

### Reuse

DCGs defined in RFC 2616:
  * `abs_path`
  * `absoluteURI`
  * `authority`
  * `host`
  * `port`
  * `rel_path`
  * `relativeURI`
  * `URI-reference`

@see RFC 2396

### Length

The HTTP protocol does not place any a priori limit on the length of a URI.

Servers MUST be able to handle the URI of any resource they serve,
 and SHOULD be able to handle URIs of unbounded length if they provide
 `GET`-based forms that could generate such URIs.

A server SHOULD return 414 (Request-URI Too Long) status
 if a URI is longer than the server can handle.

Note: Servers ought to be cautious about depending on URI lengths
above 255 bytes, because some older client or proxy
implementations might not properly support these lengths.

## Comparison

When comparing two URIs to decide if they match or not,
 a client SHOULD use a case-sensitive octet-by-octet comparison
 of the entire URIs, with these exceptions:
  - A port that is empty or not given is equivalent to
    the default port for that URI-reference;
  - Comparisons of host names MUST be case-insensitive;
  - Comparisons of scheme names MUST be case-insensitive;
  - An empty `abs_path` is equivalent to an `abs_path` of "/".
    Characters other than those in the "reserved" and "unsafe" sets
    (see RFC 2396) are equivalent to their ""%" HEX HEX" encoding.

### Example

The following three URIs are equivalent:
~~~{.uri}
[1]   http://abc.com:80/~smith/home.html
[2]   http://ABC.com/%7Esmith/home.html
[3]   http://ABC.com:/%7esmith/home.html
~~~

--

@author Wouter Beek
@see RFC 2616
@version 2013/07, 2013/12
*/



%! http_URL(
%!   -Tree:compound,
%!   ?Host:list(atomic),
%!   ?Port:integer,
%!   ?Path:list(list(atom)),
%!   ?Query:atom
%! )//
% The "http" scheme is used to locate network resources via the HTTP protocol.
% This DCG rule defines the scheme-specific syntax and semantics for
% HTTP URLs.
%
% # Syntax
%
% ~~~{.abnf}
% http_URL = "http:" "//" host [ ":" port ] [ abs_path [ "?" query ]]
% ~~~
%
% ## Absent `abs_path`
%
% If the `abs_path` is not present in the URL,
% it MUST be given as "/" when used as a Request-URI for a resource.
%
% ## Absent `port`
%
% If the port is empty or not given, port 80 is assumed.
%
% # Semantics
%
% The semantics are that the identified resource is located at
% the server listening for TCP connections on that port of that host,
% and the Request-URI for the resource is `abs_path`.
%
% # Pragmatics
%
% ## Domain name
%
% If a proxy receives a host name which is not a fully qualified domain name,
% it MAY add its domain to the host name it received.
% If a proxy receives a fully qualified domain name,
% the proxy MUST NOT change the host name.
%
% ## IP address
%
% The use of IP addresses in URLs SHOULD be avoided whenever possible
% (see RFC 1900).

% @param Tree A parse tree.
% @param Host
% @param Port An integer representing a port.
%        If the port is empty or not given, port 80 is assumed.
% @param Path
% @param Query

http_url(T0, Host, Port, Path, Query) -->
  % Schema prefix.
  "http://",

  % Host.
  rfc2396_host(T1, Host),

  % Optional port.
  (
    "", {var(Port), Port = 80}
  ;
    ":'", rfc2396_port(T2, Port)
  ),

  % Optional absolute path and query.
  (
    "", {var(Path), var(Query)}
  ;
    % Absolute path.
    rfc2396_absolute_path(T3, Path),

    % Optional query.
    (
      "", {var(Query)}
    ;
      "?", rfc2396_query(T4, Query)
    )
  ),
  {parse_tree(http_url, [T1,T2,T3,T4], T0)}.


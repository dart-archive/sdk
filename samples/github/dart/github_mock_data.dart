// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This file contains a mapping of resources to responses for the mock github
// server.

// TODO(zerny): Find a better way of running the mock server than 'on-device'.
// For the time being, this is the easiest setup for development because it
// eliminates the need to communicate with any external entities. The downside
// is an increased application size due to a larger snapshot and an increased
// battery consumption because the device is running both client and server.

String githubMockData404 = r"""HTTP/1.1 404 Not Found
Server: GitHubMock.com
Content-Length: 3
Status: 404 Not Found

{}
""";

Map<String, String> githubMockData = {
    "users/dart-lang": r"""HTTP/1.1 200 OK
Server: GitHubMock.com
Date: Mon, 20 Apr 2015 07:15:01 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 1338
Status: 200 OK
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 59
X-RateLimit-Reset: 1429517701
Cache-Control: public, max-age=60, s-maxage=60
Last-Modified: Mon, 20 Apr 2015 07:05:19 GMT
ETag: "5af2fef807e0d5372a3d5c17ce28ab30"
Vary: Accept
X-GitHub-Media-Type: github.v3
X-XSS-Protection: 1; mode=block
X-Frame-Options: deny
Content-Security-Policy: default-src 'none'
Access-Control-Allow-Credentials: true
Access-Control-Expose-Headers: ETag, Link, X-GitHub-OTP, X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset, X-OAuth-Scopes, X-Accepted-OAuth-Scopes, X-Poll-Interval
Access-Control-Allow-Origin: *
X-GitHub-Request-Id: 57398502:1416:E988BA8:5534A775
Strict-Transport-Security: max-age=31536000; includeSubdomains; preload
X-Content-Type-Options: nosniff
Vary: Accept-Encoding
X-Served-By: 474556b853193c38f1b14328ce2d1b7d

{
  "login": "dart-lang",
  "id": 1609975,
  "avatar_url": "https://avatars.githubusercontent.com/u/1609975?v=3",
  "gravatar_id": "",
  "url": "https://api.github.com/users/dart-lang",
  "html_url": "https://github.com/dart-lang",
  "followers_url": "https://api.github.com/users/dart-lang/followers",
  "following_url": "https://api.github.com/users/dart-lang/following{/other_user}",
  "gists_url": "https://api.github.com/users/dart-lang/gists{/gist_id}",
  "starred_url": "https://api.github.com/users/dart-lang/starred{/owner}{/repo}",
  "subscriptions_url": "https://api.github.com/users/dart-lang/subscriptions",
  "organizations_url": "https://api.github.com/users/dart-lang/orgs",
  "repos_url": "https://api.github.com/users/dart-lang/repos",
  "events_url": "https://api.github.com/users/dart-lang/events{/privacy}",
  "received_events_url": "https://api.github.com/users/dart-lang/received_events",
  "type": "Organization",
  "site_admin": false,
  "name": "Dart",
  "company": null,
  "blog": "https://www.dartlang.org",
  "location": "",
  "email": "",
  "hireable": null,
  "bio": "Productive language, libraries, and tools for client and server development",
  "public_repos": 132,
  "public_gists": 0,
  "followers": 0,
  "following": 0,
  "created_at": "2012-04-03T23:36:55Z",
  "updated_at": "2015-04-20T07:05:19Z"
}
""",
    "repos/dart-lang/fletch": r"""HTTP/1.1 200 OK
Server: GitHubMock.com
Date: Tue, 21 Apr 2015 08:44:30 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 5972
Status: 200 OK
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 57
X-RateLimit-Reset: 1429606274
Cache-Control: public, max-age=60, s-maxage=60
Last-Modified: Tue, 21 Apr 2015 07:42:13 GMT
ETag: "c43897b5cdfb9bf72255f73c476ccf58"
Vary: Accept
X-GitHub-Media-Type: github.v3
X-XSS-Protection: 1; mode=block
X-Frame-Options: deny
Content-Security-Policy: default-src 'none'
Access-Control-Allow-Credentials: true
Access-Control-Expose-Headers: ETag, Link, X-GitHub-OTP, X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset, X-OAuth-Scopes, X-Accepted-OAuth-Scopes, X-Poll-Interval
Access-Control-Allow-Origin: *
X-GitHub-Request-Id: 026D42C3:531F:177BB66:55360DED
Strict-Transport-Security: max-age=31536000; includeSubdomains; preload
X-Content-Type-Options: nosniff
Vary: Accept-Encoding
X-Served-By: 2811da37fbdda4367181b328b22b2499

{
  "id": 29306978,
  "name": "fletch",
  "full_name": "dart-lang/fletch",
  "owner": {
    "login": "dart-lang",
    "id": 1609975,
    "avatar_url": "https://avatars.githubusercontent.com/u/1609975?v=3",
    "gravatar_id": "",
    "url": "https://api.github.com/users/dart-lang",
    "html_url": "https://github.com/dart-lang",
    "followers_url": "https://api.github.com/users/dart-lang/followers",
    "following_url": "https://api.github.com/users/dart-lang/following{/other_user}",
    "gists_url": "https://api.github.com/users/dart-lang/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/dart-lang/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/dart-lang/subscriptions",
    "organizations_url": "https://api.github.com/users/dart-lang/orgs",
    "repos_url": "https://api.github.com/users/dart-lang/repos",
    "events_url": "https://api.github.com/users/dart-lang/events{/privacy}",
    "received_events_url": "https://api.github.com/users/dart-lang/received_events",
    "type": "Organization",
    "site_admin": false
  },
  "private": false,
  "html_url": "https://github.com/dart-lang/fletch",
  "description": "Implement highly concurrent apps in the Dart programming language (experimental).",
  "fork": false,
  "url": "https://api.github.com/repos/dart-lang/fletch",
  "forks_url": "https://api.github.com/repos/dart-lang/fletch/forks",
  "keys_url": "https://api.github.com/repos/dart-lang/fletch/keys{/key_id}",
  "collaborators_url": "https://api.github.com/repos/dart-lang/fletch/collaborators{/collaborator}",
  "teams_url": "https://api.github.com/repos/dart-lang/fletch/teams",
  "hooks_url": "https://api.github.com/repos/dart-lang/fletch/hooks",
  "issue_events_url": "https://api.github.com/repos/dart-lang/fletch/issues/events{/number}",
  "events_url": "https://api.github.com/repos/dart-lang/fletch/events",
  "assignees_url": "https://api.github.com/repos/dart-lang/fletch/assignees{/user}",
  "branches_url": "https://api.github.com/repos/dart-lang/fletch/branches{/branch}",
  "tags_url": "https://api.github.com/repos/dart-lang/fletch/tags",
  "blobs_url": "https://api.github.com/repos/dart-lang/fletch/git/blobs{/sha}",
  "git_tags_url": "https://api.github.com/repos/dart-lang/fletch/git/tags{/sha}",
  "git_refs_url": "https://api.github.com/repos/dart-lang/fletch/git/refs{/sha}",
  "trees_url": "https://api.github.com/repos/dart-lang/fletch/git/trees{/sha}",
  "statuses_url": "https://api.github.com/repos/dart-lang/fletch/statuses/{sha}",
  "languages_url": "https://api.github.com/repos/dart-lang/fletch/languages",
  "stargazers_url": "https://api.github.com/repos/dart-lang/fletch/stargazers",
  "contributors_url": "https://api.github.com/repos/dart-lang/fletch/contributors",
  "subscribers_url": "https://api.github.com/repos/dart-lang/fletch/subscribers",
  "subscription_url": "https://api.github.com/repos/dart-lang/fletch/subscription",
  "commits_url": "https://api.github.com/repos/dart-lang/fletch/commits{/sha}",
  "git_commits_url": "https://api.github.com/repos/dart-lang/fletch/git/commits{/sha}",
  "comments_url": "https://api.github.com/repos/dart-lang/fletch/comments{/number}",
  "issue_comment_url": "https://api.github.com/repos/dart-lang/fletch/issues/comments{/number}",
  "contents_url": "https://api.github.com/repos/dart-lang/fletch/contents/{+path}",
  "compare_url": "https://api.github.com/repos/dart-lang/fletch/compare/{base}...{head}",
  "merges_url": "https://api.github.com/repos/dart-lang/fletch/merges",
  "archive_url": "https://api.github.com/repos/dart-lang/fletch/{archive_format}{/ref}",
  "downloads_url": "https://api.github.com/repos/dart-lang/fletch/downloads",
  "issues_url": "https://api.github.com/repos/dart-lang/fletch/issues{/number}",
  "pulls_url": "https://api.github.com/repos/dart-lang/fletch/pulls{/number}",
  "milestones_url": "https://api.github.com/repos/dart-lang/fletch/milestones{/number}",
  "notifications_url": "https://api.github.com/repos/dart-lang/fletch/notifications{?since,all,participating}",
  "labels_url": "https://api.github.com/repos/dart-lang/fletch/labels{/name}",
  "releases_url": "https://api.github.com/repos/dart-lang/fletch/releases{/id}",
  "created_at": "2015-01-15T16:42:05Z",
  "updated_at": "2015-04-21T07:42:13Z",
  "pushed_at": "2015-04-21T07:42:13Z",
  "git_url": "git://github.com/dart-lang/fletch.git",
  "ssh_url": "git@github.com:dart-lang/fletch.git",
  "clone_url": "https://github.com/dart-lang/fletch.git",
  "svn_url": "https://github.com/dart-lang/fletch",
  "homepage": "",
  "size": 6846,
  "stargazers_count": 68,
  "watchers_count": 68,
  "language": "Dart",
  "has_issues": true,
  "has_downloads": true,
  "has_wiki": true,
  "has_pages": false,
  "forks_count": 3,
  "mirror_url": null,
  "open_issues_count": 8,
  "forks": 3,
  "open_issues": 8,
  "watchers": 68,
  "default_branch": "master",
  "organization": {
    "login": "dart-lang",
    "id": 1609975,
    "avatar_url": "https://avatars.githubusercontent.com/u/1609975?v=3",
    "gravatar_id": "",
    "url": "https://api.github.com/users/dart-lang",
    "html_url": "https://github.com/dart-lang",
    "followers_url": "https://api.github.com/users/dart-lang/followers",
    "following_url": "https://api.github.com/users/dart-lang/following{/other_user}",
    "gists_url": "https://api.github.com/users/dart-lang/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/dart-lang/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/dart-lang/subscriptions",
    "organizations_url": "https://api.github.com/users/dart-lang/orgs",
    "repos_url": "https://api.github.com/users/dart-lang/repos",
    "events_url": "https://api.github.com/users/dart-lang/events{/privacy}",
    "received_events_url": "https://api.github.com/users/dart-lang/received_events",
    "type": "Organization",
    "site_admin": false
  },
  "network_count": 3,
  "subscribers_count": 55
}
"""
};

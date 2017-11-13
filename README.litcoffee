# CouchDB JWT Auth Proxy nginx.conf generator

[![Travis Build][travis]](https://travis-ci.org/nhz-io/nhz-io-slush-jwt-auth-proxy-conf)
[![NPM Version][npm]](https://www.npmjs.com/package/@nhz.io/slush-jwt-auth-proxy-conf)

> Nginx ([openresty]) configuration generator to act as [JWT] [Proxy Authentication] Gate for [CouchDB].

## Install

```bash
npm i -g slush @nhz.io/slush-jwt-auth-proxy-conf
```

## Usage
```bash
mkdir jwt-auth-proxy && cd jwt-auth-proxy

slush @nhz.io/slush-jwt-auth-proxy-conf
```

## Secrets
* `JWT_SECRET` - key used to sign and verify JWT with
* `COUCH_PROXY_SECRET` - key used to generate [x_auth_token]

## Effect

* JWT Auth Proxy will process requests and proxy them to [CouchDB]
* Requests are authorized by verifying signature and expiration of JWT
* JWT comes either from headers, url
* JWT will always be cached in the cookie
* JWT carries payload which contains `username` and `roles` which will be proxied in headers to [CouchDB]
* Invalid JWT results in **HTTP 403**

## JWT

JWT Payload example:

```json
{
  "exp": 1510356100,
  "iat": 1510356220,
  "data": {
    "user": "boss",
    "roles": ["_admin"]
  }
}
```

JWT with such payload will grant admin access to **boss** user for 120 seconds

### JWT From headers (Low priority)

* JWT be extracted from `X-JWT-Auth` header
* Request will be proxied to [CouchDB] as is
* JWT will be cached in the cookie

### JWT From URL (High priority)

Process URLs of form: `http://` `HOST` : `PORT` `/` `${TOKEN_PREFIX}` `JWT` `PATH`

* Extract JWT from URL
* `PATH` will be proxied to [CouchDB]
* JWT will be cached in the cookie

## CouchDB configuration

Make sure `local.ini` contains:

```
[chttpd]
authentication_handlers = {couch_httpd_auth, proxy_authentication_handler}

[couch_httpd_auth]
proxy_use_secret = true
```

### Generated files

* `nginx.conf` - [openresty] configuration
* `package.json` - configuration settings are stored here for later reconfiguration

### Notes:

* Intended to run in [Docker]
* JWT by URL is preferred method (rather than headers)
* You can use JWT by URL as a key to open session, (JWT in cookie) and rest of requests with basename `/`
* You can revisit the configuration later by running `slush @nhz.io/slush-jwt-auth-proxy-conf` again
* You can distribute the `package.json` and regenerate `nginx.conf` anywhere by running `npm i`
* Use [jwt-hs256-proxy-auth-token] to generate tokens

## Imports

> Builtins

    path      = require 'path'

> General

    gulp      = require 'gulp'
    pump      = require 'pump'
    inquirer  = require 'inquirer'
    transform = require 'vinyl-transform'
    map       = require 'map-stream'

> Gulp plugins

    rename    = require 'gulp-rename'
    template  = require 'gulp-template'
    sequence  = (require 'run-sequence').use gulp

> String utils imports

    slugify   = require 'slugify'

> Global package.json variable (Corresponds to current directory)

    pkg       = try require './package.json'

> Global flag which marks regeneration run (will be cleared if no package.json found)

    regen     = true

## Defaults

    def = {
      pkgName: 'nginx.conf'
      pkgVersion: '1.0.0'

      HOST: ''
      PORT: 80

      COUCH_HOST: 'couch'
      COUCH_PORT: 5984
      COUCH_SCHEMA: 'http'

> This is the only secret here, base JWT token to use when there is none.
> Could be used to setup default unpriviledged access.
> MUST HAVE VERY LONG expiration

      DEFAULT_JWT_TOKEN: ''

> Those are not secrets, those are names of ENV variables

      JWT_SECRET: 'JWT_SECRET'
      COUCH_PROXY_SECRET: 'COUCH_PROXY_SECRET'

      JWT_COOKIE_NAME: 'JWT'
      JWT_HEADER_NAME: 'X-JWT-Auth'
      JWT_TOKEN_PREFIX: '!'

      ERROR_LOG: '/var/log/nginx/error.log warn'
      PID_PATH: '/var/run/nginx.pid'

      REWRITE: '^(/.*) $1'
      ROLES: []

      defaultRoutes: {
        '/': []
        '^/_': ['_admin']
        '^/_session': []
        '^/_users': []
      }
    }

## Prompts

### New configuration prompt

    newConfigurationPrompt = {
      name: 'task'
      type: 'list'
      message: 'JWT Auth Proxy configuration'
      choices: [
        'Create nginx.conf'
        'Done'
      ]
    }

### Reconfiguration prompt

    reconfigurationPrompt = {
      name: 'task'
      type: 'list'
      message: 'JWT Auth Proxy configuration'
      choices: [
        'Configure Server'
        'Configure Proxy'

> Route editing is unfinished, so disabled for now

        # 'Configure Routes'
        'Regenerate'
        'Done'
      ]
    }

### Route configuration prompts

    routesPrompt = {
      name: 'task'
      type: 'list'
      message: 'JWT Auth Proxy Route configuration'
      newChoices: [
        'Add Route'
        'Done'
      ],
      reconfigureChoices: [
        'Add Route'
        'Remove Routes'
        'Edit Routes'
        'View Routes'
        'Done'
      ]
    }

    removeRoutesPrompt = {
      name: 'routes'
      type: 'checkbox'
      message: 'Select routes to remove'
      choices: ['Done']
    }

    editRoutesPrompt = {
      name: 'routes'
      type: 'list'
      message: 'Select route to edit'
      choices: ['Done']
    }

    viewRoutesPrompt = {
      name: 'routes'
      type: 'list'
      message: 'Select route to edit'
      choices: ['Done']
    }

    addRoutePropmts = [
      {
        name: 'MATCH'
        message: 'Match regexp'
        validate: true
      }
      {
        name: 'ROLES'
        message: 'Required roles (comma separated)'
        default: []
      }
      {
        name: 'REWRITE'
        message: 'Rewrite rule'
        default: '^(/.*) $1'
      }
    ]

### Server configuration prompts

    serverPrompts = [
      {
        name: 'HOST'
        message: 'JWT Proxy Auth server host'
        default: (pkg.server or def).HOST
      }
      {
        name: 'PORT'
        message: 'JWT Proxy Auth server port'
        default: (pkg.server or def).PORT
      }
      {
        name: 'COUCH_HOST'
        message: 'CouchDB host to proxy'
        default: (pkg.server or def).COUCH_HOST
      }
      {
        name: 'COUCH_PORT'
        message: 'CouchDB port to proxy'
        default: (pkg.server or def).COUCH_PORT
      }
      {
        name: 'COUCH_SCHEMA'
        message: 'CouchDB protocol schema'
        default: (pkg.server or def).COUCH_SCHEMA
      }
      {
        name: 'ERROR_LOG'
        message: 'Error log path and level'
        default: (pkg.server or def).ERROR_LOG
      }
      {
        name: 'PID_PATH'
        message: 'Nginx pid file path'
        default: (pkg.server or def).PID_PATH
      }
    ]

### Proxy Auth configuration prompts

    proxyPrompts = [
      {
        name: 'JWT_SECRET'
        message: 'JWT Secret ENV Variable name'
        default: (pkg.proxy or def).JWT_SECRET
      }
      {
        name: 'COUCH_PROXY_SECRET'
        message: 'CouchDB Proxy Auth secret ENV Variable name'
        default: (pkg.proxy or def).COUCH_PROXY_SECRET
      }
      {
        name: 'JWT_COOKIE_NAME'
        message: 'JWT token cookie name'
        default: (pkg.proxy or def).JWT_COOKIE_NAME
      }
      {
        name: 'JWT_HEADER_NAME'
        message: 'JWT header name'
        default: (pkg.proxy or def).JWT_HEADER_NAME
      }
      {
        name: 'JWT_TOKEN_PREFIX'
        message: 'JWT token prefix'
        default: (pkg.proxy or def).JWT_TOKEN_PREFIX
      }
    ]

## Tasks

### Package preloader

    gulp.task 'load-pkg', ->
      pkg = try require (path.resolve process.cwd(), 'package.json') catch then regen = false
      pkg = Object.assign {}, def, pkg

      return

### Server configuration

    gulp.task '_server', -> try answers = await inquirer.prompt serverPrompts

    gulp.task 'server', (cb) -> sequence 'load-pkg', '_server', '_regenerate',  cb

### Proxy configuration

    gulp.task '_proxy', -> try answers = await inquirer.prompt proxyPrompts

    gulp.task 'proxy', (cb) -> sequence 'load-pkg', '_proxy', '_regenerate', cb

### Routes configuration menu

    gulp.task '_view-routes', ->
      anwsers = await inquirer.prompt [viewRoutesPrompt]

    gulp.task 'view-routes', -> sequence 'load-pkg', '_view-routes'

    gulp.task '_edit-routes', ->
      answers = await inquirer.prompt [editRoutesPrompt]

    gulp.task 'edit-routes', (cb) -> sequence 'load-pkg', '_edit-routes'

    gulp.task '_delete-routes', ->
      answers = await inqurer.prompt [deleteRoutesPrompt]

    gulp.task 'delete-routes', -> sequence 'load-pkg', '_delete-routes'

    gulp.task '_routes', ->
      prompt = Object.assign {}, routesPrompt

      prompt.choices = if regen then prompt.reconfigureChoices else prompt.newChoices

      answers = await inquirer.prompt [prompt]

      console.log JSON.stringify answers, null, 2

      new Promise (res) ->

        switch answers.task

          when 'Add Route' then sequence '_server', res

          when 'Remove Routes' then sequence '_remove_routes', '_regenerate', '_routes', res

          when 'Edit Routes' then sequence '_edit_routes', '_regenerate', '_routes', res

          when 'View Routes' then sequence '_view_routes', '_regenerate', '_routes', res

          else res()

    gulp.task 'routes', (cb) -> sequence 'load-pkg', '_routes', cb


### Main menu

    gulp.task '_default', ->

      prompt = if regen then reconfigurationPrompt else newConfigurationPrompt

      loop
        answers = await inquirer.prompt [prompt]

        res = await new Promise (res) -> switch answers.task
          when 'Create nginx.conf' then sequence '_server', '_proxy', '_regenerate', res

          when 'Configure Server' then sequence '_server', '_regenerate', res

          when 'Configure Proxy' then sequence '_proxy', '_regenerate', res

          when 'Configure Routes' then sequence '_routes', '_regenerate', res

          when 'Regenerate' then sequence '_regenerate', res

          else res 'exit'

        if res is 'exit' then return

        prompt = reconfigurationPrompt

    gulp.task 'default', (cb) -> sequence 'load-pkg', '_default', cb

### Regenerate *nginx.conf* and *package.json*

    gulp.task '_regenerate', ->

      server = pkg.server or {}

      proxy = pkg.proxy or {}

      defaultRoutes = pkg.defaultRoutes

      routes = Object.assign {}, defaultRoutes, (pkg.routes or {})

> Remap routes into consumable form

      routes = (Object.keys routes).map (MATCH) ->

        value = routes[MATCH]

        if typeof value is 'string' then return { MATCH, REWRITE: value }

        if Array.isArray value then return { MATCH, ROLES: value }

        { MATCH, REWRITE: value?.rewrite or '', ROLES: value?.roles or [] }

> Generate locations from routes fixing rewrite and roles

      locations = routes.map ({MATCH, REWRITE, ROLES}) ->

> Transform rewrite rule or use default

        REWRITE =
          if REWRITE then REWRITE.replace /^(.+) +(.+)/, '$1 /rewrite$2'

          else '^(/.*) /rewrite$1'

> Transform roles

        ROLES = ROLES.join ', '

        { MATCH, REWRITE, ROLES }

> Create template context

      context = Object.assign {}, pkg, server, proxy, { locations, routes }

> JWT_COOKIE_NAME and JWT_HEADER_NAME need *snake_case* version

      context.JWT_COOKIE_NAME_snake_case = (slugify context.JWT_COOKIE_NAME, '_').toLowerCase()
      context.JWT_HEADER_NAME_snake_case = (slugify context.JWT_HEADER_NAME, '_').toLowerCase()

      console.log JSON.stringify context, null, 2

      await pump [
        gulp.src __dirname + '/templates/**'

        (template context).on 'error', (err) -> console.log 'OMG', err

        rename (f) -> if f.basename[0] is '_' then f.basename = ".#{ f.basename.slice 1 }"

> Prettify package.json

        transform (filename) -> map (chunk, next) ->
          if filename.match 'package.json'
            next null, JSON.stringify (JSON.parse chunk), null, 2
          else
            next null, chunk

        gulp.dest './'
      ]

      return

    gulp.task 'regenerate', (cb) -> sequence 'load-pkg', '_regenerate', cb

## Version 1.0.0

## License [MIT](LICENSE)

[travis]: https://img.shields.io/travis/nhz-io/nhz-io-slush-jwt-auth-proxy-conf.svg?style=flat
[npm]: https://img.shields.io/npm/v/@nhz.io/slush-jwt-auth-proxy-conf.svg?style=flat
[x_auth_roles]: http://docs.couchdb.org/en/2.1.1/config/auth.html#couch_httpd_auth/x_auth_roles
[x_auth_token]: http://docs.couchdb.org/en/2.1.1/config/auth.html#couch_httpd_auth/x_auth_token
[Proxy Authentication]: http://docs.couchdb.org/en/2.1.1/api/server/authn.html#api-auth-proxy
[openresty]: https://github.com/openresty/lua-nginx-module
[jwt-hs256-proxy-auth-token]: https://github.com/nhz-io/nhz-io-jwt-hs256-proxy-auth-token
[JWT]: https://github.com/auth0/node-jsonwebtoken
[CouchDB]: https://github.com/apache/couchdb
[Docker]: https://www.docker.com/
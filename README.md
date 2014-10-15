node-webhooks for apigee
========================

## Easily Create Webhooks

1. Create a new nodejs app packaged for apigee, with node-webhooks as a dependency in `node_modules`.
2. Create a `main` script for apigee that creates a new instance of the node-webhooks listener server.
3. Create a `hooks/` directory in the app root.  This will be the root of the tree for webhook scripts.  In each folder, create a script called `webhook` that will receive the POSTed params and run the webhook action.


### Usage

The following options can be passed to the Webhook constructor:

```coffee
hooks:
  "urlPath":
    "type": ["node"|"shell"] (optional)
    "dir": "localPath (relative to baseDir)" (optional)
    "mod": [loaded CommonJS module with hook fn] (optional)

# For default type and urlPath == localPath, use: "urlPath": true

options:
  namespace: "webhooks"
  script:    "./webhook"
  type:      "node"
  basedir:   path.join process.cwd(), "hooks"
```

#### Example:
```coffee
hooks =
  "redmine": true
  "pivotal-asana":
    mod: new (require "./hooks/pivotal-asana/webhook") projectMap, "MobileApps"
  "asana-pivotal":
    mod: new (require "./hooks/asana-pivotal/webhook") projectMap, "MobileApps"

basedir = path.join process.cwd(), "hooks"

app = new Webhooks hooks, basedir: basedir
app.start()
```

With default options, the server will listen at:

    username.apigee.com/webhooks/path

Params posted to that URL will run the script:

    hooks/path/webhooks.js

### Scripting

The server will pass all POSTed params to the local script.

#### Shell
For shell scripts it will pass params as arguments in `key=value` pairs.

#### Node
For node scripts it will `require` the node script as a CommonJS module. Then it calls the exported hook function with the params object as the first argument, i.e.:

```coffee
exports.hook = (params, callback) -> ...
```

Any errors will be passed to the callback function.  If the callback returns with a null/empty/undefined/non-true value, the server will respond with `200 OK`.

### Security

Use apigee's tools to manage authorization, API keys, and rate limiting.

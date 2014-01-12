node-webhooks
=============

## Easily Create Webhooks

1. Create a script called `webhook` in the directory you wish to
   run it from.
2. Run `webhooks hash` command in same directory as `webhook` script to
   get the webhook key.
3. Boot webhooks with `webhooks start`
4. POST to your webhooks server using your webhook key, e.g.
   curl -d "param1=val1" http://localhost:10010/CrfYl8CssJ7Jo0dYryVJYMV44CC5AcLi0At%2FF0DXa5TTiSQs%3D

### Usage

```sh
Usage: webhooks [start|hash] [options]
Starts a webhook listener server that runs a node or shell script in the
local directory.


  -k, --secret       secret for URL hash (default: "keyboard cat")
  -n, --namespace    namespace for URL hash (default: none)
  -p, --port         port for webhook listener (default: 10010)
  -s, --script       filename of local script (default: ./webhook)
  -t, --type         type of local script (node or shell) (default: shell)
```

### Scripting

The server will pass all POSTed params to the local script.

#### Shell
For shell scripts it will pass params as arguments in `key=value` pairs.

#### Node
For node scripts it will `require` the node script as a CommonJS module.
Then it calls the exported hook function with the params object as the
first argument, i.e.:

```coffee
exports.hook = (params, callback) -> ...
```

Any errors will be passed to the callback function.  If the callback
returns with a null/empty/undefined/non-true value, the server will
respond with `200 OK`.

### Security

Use this with much caution. I wouldn't use this on a production machine.
For increased security, set secret when running `webhook hash` or
`webhook start` to encrypt using a custom keyphrase.

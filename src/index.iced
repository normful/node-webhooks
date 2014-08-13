"use strict"

express  = require "express"
fs       = require "fs"
http     = require "http"
path     = require "path"
{exec}   = require "child_process"


extend = (target, sources...) ->
  target[key] = val for key, val of source for source in sources
  target


class Webhooks
  defaults:
    namespace: "webhooks"
    port:      10010
    script:    "./webhook"
    type:      "node"
    basedir:   path.join process.cwd(), "hooks"

  constructor: (hooks, options = {}) ->
    options   = extend {}, @defaults, options
    @[key]    = options[key] for key of @defaults
    @app    or= express()
    @loadHooks hooks

  loadHooks: (hooksToLoad = {}, autocb = ->) ->
    throw new Error "hooks must be specified" unless (Object.keys hooksToLoad).length

    @hooks = {}
    await
      for hook, hookopts of hooksToLoad
        type = hookopts.type or @type
        dir  = hookopts.dir or hook
        loc  = path.join @basedir, dir, @script

        if hookopts.hook or hookopts = hookopts.mod
          @hooks[dir] = hookopts
        else
          @loadHook type, loc, defer hook
          @hooks[dir] = hook

    console.log "hooks loaded"

  loadHook: (type, loc, autocb) ->
    error = (loc) -> throw new Error "unable to load webhook module at #{loc}"

    switch type
      when "node"
        try
          mod = require loc
          console.log "loaded node webhook at #{loc}"
        catch e
          error loc
        finally
          return mod
      else
        await fs.exists loc, defer exists
        unless exists then return error loc
        console.log "loaded shell webhook at #{loc}"
        loc

  lastRoute: (req, res, next) ->
    res.status 404
    if req.accepts('json') then res.send error: 'Not found'
    else                        res.type('txt').send 'Not found'

  errorMiddleware: (err, req, res, next) ->
    res.status err.status || 500
    res.send http.STATUS_CODES[res.status]

  start: ->
    @app.use express.bodyParser()
    @app.use express.errorHandler()
    @app.use express.logger()

    @app.use @app.router
    @app.post (path.join "/", @namespace, ":hook"), @listenForWebhook

    @app.use @lastRoute
    @app.use @errorMiddleware

    @app.listen @port

  listenForWebhook: (req, res, next) =>
    unless dir = req.params.hook and hook = hooks[dir]
      console.warn "missing hook", req.params.hook
      return res.send 404

    executeHook = switch typeof hook
      when "string" then @executeShellScript
      else @executeNodeModule

    await executeHook hook, req.body, defer err
    return next err if err

    res.send 200

  sane: (value) -> /^[a-zA-Z0-9 _\-+=,.;:'"?!@#%\^&*()<>\[\]{}|\\/\t]+$/.test value

  executeShellScript: (path, params, autocb) =>
    textParams  = ("#{key}=\"#{value}\"" for key, value of params when @sane value)
    cmdWithArgs = path + " " + textParams.join " "
    await exec cmdWithArgs, {cwd: path.dirname path}, defer err
    err

  executeNodeModule: (mod, params, autocb) =>
    await mod.hook params, defer err
    err


module.exports = Webhooks

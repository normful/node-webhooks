"use strict"

express  = require "express"
domain   = require "domain"
fs       = require "fs"
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

  constructor: (options = {}) ->
    options   = extend {}, @defaults, options
    @[key]    = options[key] for key of @defaults
    @app    or= express()

  start: ->
    @app.use express.bodyParser()
    @app.use express.errorHandler()
    @app.use express.logger()
    @app.post (path.join "/", @namespace, ":hook"), @listenForWebhook
    @app.listen @port

  listenForWebhook: (req, res, next) =>
    unless dir = req.params.hook
      console.warn "missing hook", req.params.hook
      return res.send 404

    fullpath = path.join @basedir, dir
    await fs.exists fullpath, defer exists
    unless exists
      console.warn "directory does not exist!", fullpath
      return res.send 404

    console.info dir

    executeHook = switch @type
      when "node" then @executeNodeModule
      else @executeShellScript

    await executeHook fullpath, req.body, defer err
    return next err if err

    res.send 200

  sane: (value) -> /^[a-zA-Z0-9 _\-+=,.;:'"?!@#%\^&*()<>\[\]{}|\\/\t]+$/.test value

  executeShellScript: (dir, params, autocb) =>
    textParams  = ("#{key}=\"#{value}\"" for key, value of params when @sane value)
    cmdWithArgs = @script + " " + textParams.join " "
    await exec cmdWithArgs, {cwd: dir}, defer err
    err

  executeNodeModule: (dir, params, autocb) =>
    mod = require path.join dir, @script
    await mod.hook params, defer err
    err


module.exports = Webhooks

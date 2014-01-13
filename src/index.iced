"use strict"

express  = require "express"
crypto   = require "crypto"
assert   = require "assert"
domain   = require "domain"
fs       = require "fs"
path     = require "path"
{exec}   = require "child_process"


extend = (target, sources...) ->
  target[key] = val for key, val of source for source in sources
  target


class Webhook
  defaults:
    ALGORITHM: "cast5-cbc"
    FORMAT:    "base64"
    namespace: ""
    port:      process.env.PORT or 10010
    script:    "./webhook"
    secret:    process.env.WH_SECRET or "keyboard cat"
    type:      "shell"

  constructor: (options = {}) ->
    options   = extend {}, @defaults, options
    @[key]    = options[key] for key of @defaults
    @app    or= express()
    @cwd    or= process.cwd()

  start: ->
    @app.use express.bodyParser()
    @app.use express.errorHandler()
    @app.use express.logger()
    @app.post "#{@namespace}/:hash", @listenForWebhook
    @app.listen @port

  listenForWebhook: (req, res, next) =>
    unless req.params.hash
      console.warn "missing hash", req.params.hash
      return res.send 404

    try
      dir = @decrypt req.params.hash, @secret
    catch err
      if err.toString().match /DecipherFinal/
        console.warn "could not decipher", req.params.hash
        return res.send 404
      else
        return next err

    await fs.exists dir, defer exists
    unless exists
      console.warn "directory does not exist!", dir
      return res.send 404

    console.info dir

    executeHook = switch @type
      when "node" then @executeNodeModule
      else @executeShellScript

    await executeHook dir, req.body, defer err
    return next err if err

    res.send 200

  executeShellScript: (dir, params, autocb) =>
    textParams  = ("#{key}=\"#{value}\"" for key, value of params)
    cmdWithArgs = @script + " " + textParams.join " "
    await exec cmdWithArgs, {cwd: dir}, defer err
    err

  executeNodeModule: (dir, params, autocb) =>
    mod = require path.join dir, @script
    await mod.hook params, defer err
    err

  getId: -> os.hostname() + @cwd

  encrypt: (id, password) ->
    assert.ok id
    assert.ok password
    projectCipher = crypto.createCipher @ALGORITHM, password
    final  = projectCipher.update id, "utf8", @FORMAT
    final += projectCipher.final @FORMAT
    final

  decrypt: (encrypted, password) ->
    assert.ok encrypted
    assert.ok password
    projectDecipher = crypto.createDecipher @ALGORITHM, password
    final  = projectDecipher.update encrypted, @FORMAT, "utf8"
    final += projectDecipher.final "utf8"
    final

  hashCwd: (cwd = @cwd, secret = @secret) ->
    encodeURIComponent @encrypt cwd, secret


module.exports = Webhook

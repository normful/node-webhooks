"use strict"

express  = require "express"
crypto   = require "crypto"
assert   = require "assert"
domain   = require "domain"
fs       = require "fs"
path     = require "path"
{exec}   = require "child_process"


ALGORITHM = "cast5-cbc"
FORMAT    = "base64"
namespace = ""
port      = 10010
script    = "./webhook"
secret    = process.env.WH_SECRET or "keyboard cat"
type      = "shell"


pcwd      = process.cwd()
app       = express()


executeShellScript = (dir, params, autocb) ->
  textParams  = ("#{key}=\"#{value}\"" for key, value of params)
  cmdWithArgs = app.script + " " + textParams.join " "
  await exec cmdWithArgs, {cwd: dir}, defer err
  err

executeNodeModule = (dir, params, autocb) ->
  mod = require path.join dir, app.script
  await mod.hook params, defer err
  err

getId = -> os.hostname() + pcwd

encrypt = (id, password) ->
  assert.ok id
  assert.ok password
  projectCipher = crypto.createCipher ALGORITHM, password
  final  = projectCipher.update id, "utf8", FORMAT
  final += projectCipher.final FORMAT
  final

decrypt = (encrypted, password) ->
  assert.ok encrypted
  assert.ok password
  projectDecipher = crypto.createDecipher ALGORITHM, password
  final  = projectDecipher.update encrypted, FORMAT, "utf8"
  final += projectDecipher.final "utf8"
  final

hashCwd = (cwd = pcwd) ->
  encodeURIComponent encrypt cwd, app.secret

listenForWebhook = (req, res, next) ->
  unless req.params.hash
    console.warn "missing hash", req.params.hash
    return res.send 404

  try
    dir = decrypt req.params.hash, app.secret
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

  executeHook = switch app.type
    when "node" then executeNodeModule
    else executeShellScript

  await executeHook dir, req.body, defer err
  return next err if err

  res.send 200


app.use express.bodyParser()
app.use express.errorHandler()
app.use express.logger()
app.encrypt   = encrypt
app.decrypt   = decrypt
app.hashCwd   = hashCwd
app.namespace = namespace
app.script    = script
app.secret    = secret
app.port      = port
app.type      = type
app.post "#{app.namespace}/:hash", listenForWebhook


module.exports = app

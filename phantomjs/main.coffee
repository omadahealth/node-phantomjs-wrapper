system = require('system')
webpage = require('webpage')
webserver = require('webserver')
shared = require('../src/shared')


randomPort = ->
  start = 49152; end = 65535
  rv = start + Math.random() * (end - start)
  return Math.round(rv)


log = (msg) ->
  system.stdout.writeLine(msg)


pages = []


class Page

  methods = {}

  for method in shared.methods
    methods[method] = true

  asyncMethods = {}

  for method in shared.asyncMethods
    asyncMethods[method] = true


  constructor: (cb) ->
    @id = pages.length
    @page = webpage.create()
    pages.push(this)
    for event in shared.events
      do (event) =>
        @page[event] = (args...) =>
          send(type: 'pageEvent', pageId: @id, event: event, args: args)
    cb(type: 'pageCreate', pageId: @id)


  getProperty: (name, cb) ->
    val = @page[name]
    cb(args: [null, val])


  setProperty: (name, val, cb) ->
    try
      @page[name] = val
      msg = args: [null]
    catch e
      msg = args: [e.message]

    cb(msg)


  callMethod: (name, args, cb) ->
    callback = (args...) =>
      if args[0] instanceof Error then args[0] = args[0].message
      if args[0] == 'success' then args[0] = undefined
      cb(type: 'pageMethodCallback', args: args)

    if name of methods
      try
        rv = @page[name].apply(@page, args)
        callback(null, rv)
      catch e
        callback(e)
    else if name of asyncMethods
      args.push(callback)
      @page[name].apply(@page, args)


  send: (message, cb) ->
    switch message.pageMessageType
      when 'callMethod'
        @callMethod(message.name, message.args, cb)
      when 'getProperty'
        @getProperty(message.name, cb)
      when 'setProperty'
        @setProperty(message.name, message.val, cb)


send = (message) ->
  message = JSON.stringify(message)
  system.stderr.write(message + '\n')


read = ->
  message = system.stdin.readLine()

  try
    return JSON.parse(message)
  catch e
    log("#{e.message}(#{message})")
    phantom.exit()


listenPort = system.args[1] or shared.DEFAULT_PORT
server = webserver.create()
requestCb = (req, res) ->
  cb = (msg) ->
    res.statusCode = 200
    res.setHeader('Content-Type', 'application/json')
    res.write(JSON.stringify(msg) + '\n')
    res.close()

  msg = JSON.parse(req.post)

  switch msg.type
    when 'createPage'
      new Page(cb)
    when 'pageMessage'
      pages[msg.pageId].send(msg, cb)


while true
  port = randomPort()
  if server.listen("127.0.0.1:#{port}", requestCb)
    break


system.stderr.writeLine(port)
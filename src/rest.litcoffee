    Query = require('graph-common/lib/query')
    Graph = require('graph-common').Graph
    restify = require('restify')
    self = null

    class REST

      constructor: (options) ->
        self = @
        @options = options or {}
        if not @options.formatters
          @options.formatters = {}
          @options.formatters['application/json; q=0.9'] = @formatJSON

        @options.listenPort ?= 8008

        if @options.ssl
          if @options.sslKeyFile and @options.sslCertificateFile
            fs = require('fs')
            @options.certificate = fs.readFileSync(@options.sslCertificateFile)
            @options.key = fs.readFileSync(@options.sslKeyFile)
          else
            console.warn('SSL option requires you to specify sslKey and sslCert. Starting without SSL.')

        @server = restify.createServer(@options)

      @run: (argv, exit) ->
        rest = new REST()
        rest.start_graph(argv, exit, () ->
          rest.server.pre(restify.pre.sanitizePath())
          rest.server.use(restify.bodyParser())
          rest.server.get('/.*/', rest.query)
          rest.server.post('/.*/', rest.query)
          rest.server.put('/.*/', rest.query)
          rest.server.del('/.*/', rest.query)
          rest.server.listen(rest.options.listenPort, () ->
            console.log rest.server.toString()
          )
        )

      start_graph: (argv, exit, done) ->
        @graph = new Graph(REST.configuration_manager(argv), done)

      @configuration_manager: (argv) ->
        mongo_host = argv.host || process.env.DB_PORT_27017_TCP_ADDR || 'localhost'
        mongo_port = argv.port || process.env.DB_PORT_27017_TCP_PORT || '27017'
        mongo_database = argv.database || 'graph'
        mongo_uri = "mongodb://#{mongo_host}:#{mongo_port}/#{mongo_database}"

        ConfigurationManager = require('graph-common').ConfigurationManager
        return new ConfigurationManager({
          name: "Piráti Open Graph API",
          StorageManager: mongo_uri,
          logLevel: 'silly',
          logFile: 'logs/graph.log'
        })

      query: (req, res, next) ->
        switch req.method
          when "POST" then action = 'create'
          when "DELETE" then action = 'delete'
          when "PUT" then action = 'update'
          else action = 'read'

        self.graph.query(new Query(req.url, action, req.body), (query) ->
          self.passData(res, 'text/plain', query.data)
          next()
        )

      formatJSON: (req, res, body) ->
        if body instanceof Error
          res.statusCode = body.statusCode || 500
          if body.body
            body = body.body
          else
            body = message: body.message
        else
          if (Buffer.isBuffer(body))
            body = body.toString('base64')
        data = JSON.stringify(body, null, '  ')
        res.setHeader('Content-Length', Buffer.byteLength(data))
        data

      sendJson: (res, json) ->
        res.charSet('utf-8')
        res.json(json)

      passData: (res, type, data) ->
        data = '' unless data
        data = data.toString() unless typeof data is 'string'
        res.writeHead(200,
          'Content-Length': data.length,
          'Content-Type': type
        )
        res.write(data)
        res.end()

    module.exports = REST

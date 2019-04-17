gavel = require('../../../lib/gavel')
_ = require('lodash')
vm = require('vm')
util = require('util')
{assert} = require('chai')


HTTP_LINE_DELIMITER = '\n'


class World
  constructor: ->
    @codeBuffer = ''
    @commandBuffer = ''

    # Data for creation of:
    #
    # - ExpecterHttpResponse
    # - ExpectedHttpRequest
    # - ExpectedHttpMessage
    @expected = {}

    # Data for creation of:
    #
    # - HttpResponse
    # - HttpRequest
    # - HttpMessage
    @real = {}

    # Parsed HTTP objects for model valdiation
    @model = {}

    # Results of validators
    @results = {}

    # Validation verdict for the whole HTTP Message
    @booleanResult = false

    # Component relevant to the expectation, e.g. 'body'
    @component = null
    @componentResults = null

    @expectedType = null
    @realType = null

  expectBlockEval: (block, expectedReturn, callback) ->
    realOutput = @safeEval(block, callback)

    # I'm terribly sorry, but curly braces not asigned to any
    # variable in evaled string are interpreted as code block
    # not an Object literal, so I'm wrapping expected code output
    # with brackets.
    # see: http://stackoverflow.com/questions/8949274/javascript-calling-eval-on-an-object-literal-with-functions

    expectedOutput = @safeEval("(" + expectedReturn + ")", callback)

    realOutputInspect = util.inspect(realOutput)
    expectedOutputInspect = util.inspect(expectedOutput)

    try
      assert.deepEqual realOutput, expectedOutput
    catch error
      callback new Error("Output of code buffer does not equal. Expected output:\n" \
                    + expectedOutputInspect \
                    + "\nbut got: \n" \
                    + realOutputInspect + "\n" \
                    + "Evaled code block:" + "\n" \
                    + "- - - \n" \
                    + block + "\n" \
                    + "- - - ")
    callback()

  safeEval: (code, callback) ->
    # I'm terribly sorry, it's no longer possible to manipulate module require/load
    # path inside node's process. So I'm prefixing require path by hard
    # substitution in code to pretend to 'hit' is packaged module.
    #
    # further reading on node.js load paths:
    # http://nodejs.org/docs/v0.8.23/api/all.html#all_all_together

    code = code.replace("require('", "require('../../../lib/")

    try
      return eval(code)
    catch error
      callback new Error("Eval failed. Code buffer: \n\n" \
                    + code \
                    + "\nWith error: " \
                    + error)


  isValid: (cb) ->
    gavel.isValid @real, @expected, 'response', (error, result) ->
      cb error, result

  validate: (cb) ->
    gavel.validate @real, @expected, 'response',  (error, result) ->
      cb error, result

  parseHeaders: (headersString) ->
    lines = headersString.split(HTTP_LINE_DELIMITER)
    headers = {}
    for line in lines
      parts = line.split(":")
      key = parts.shift()
      headers[key.toLowerCase()] = parts.join(":").trim()
    headers

  parseRequestLine: (parsed, firstLine) ->
    firstLine = firstLine.split(' ')
    parsed.method = firstLine[0]
    parsed.uri = firstLine[1]

  parseResponseLine: (parsed, firstLine) ->
    firstLine = firstLine.split(' ')
    parsed.statusCode = firstLine[1]
    parsed.statusMessage = firstLine[2]

  parseHttp: (type, string) ->
    throw Error 'Type must be "request" or "response"' unless type == 'request' or type == 'response'

    parsed = {}

    lines = string.split HTTP_LINE_DELIMITER

    if type == 'request'
      @parseRequestLine parsed, lines.shift()
    if type == 'response'
      @parseResponseLine parsed, lines.shift()

    bodyLines = []
    headersLines = []
    bodyEntered = false
    for line in lines

      if line == ''
        bodyEntered = true
      else
        if bodyEntered
          bodyLines.push line
        else
          headersLines.push line

    parsed.headers = @parseHeaders headersLines.join(HTTP_LINE_DELIMITER)
    parsed.body = bodyLines.join HTTP_LINE_DELIMITER

    parsed

  toCamelCase: (input) ->
    result = input.replace /\s([a-z])/g, (strings) ->
      strings[1].toUpperCase()
    result

  toPascalCase: (input) ->
    result = input.replace /(\w)(\w*)/g, (g0, g1, g2) ->
      return g1.toUpperCase() + g2.toLowerCase()
    result = result.replace " ", ''

  # Debugging helper
  inspect: (data) ->
    if typeof data == 'object'
      return JSON.stringify(data, null, 2)
    else
      return data

  # Debugging helper
  throw: (data) ->
    throw new Error(@inspect(data))


module.exports = ->
  @World = World

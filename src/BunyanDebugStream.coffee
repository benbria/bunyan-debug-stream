path               = require 'path'
{Writable}         = require 'stream'

bunyan             = require 'bunyan'
colors             = require 'colors/safe'
exceptionFormatter = require 'exception-formatter'

{srcToString, applyColors, dateToString, isString} = require './utils'

# Enable colors for non-tty stdout
colors.enabled = true;

# A list of various properties for the different bunyan levels.
LEVELS = do ->
    answer = {}
    o = (level, prefix, colors) -> answer[level] = {level, prefix, colors}

    o bunyan.TRACE, 'TRACE:', ['grey']
    o bunyan.DEBUG, 'DEBUG:', ['cyan']
    o bunyan.INFO,  'INFO: ', ['green']
    o bunyan.WARN,  'WARN: ', ['yellow']
    o bunyan.ERROR, 'ERROR:', ['red']
    o bunyan.FATAL, 'FATAL:', ['magenta']

    return answer

# A list of fields to not print, either because they are boring or because we explicitly pull them
# out and format them in some special way.
FIELDS_TO_IGNORE = ['src', 'msg', 'name', 'hostname', 'pid', 'level', 'time', 'v', 'err']

# express-bunyan-logger adds a bunch of fields to the `req`, and we don't wnat to print them all.
EXPRESS_BUNYAN_LOGGER_FIELDS = [
    'remote-address', 'ip', 'method', 'url', 'referer', 'user-agent', 'body', 'short-body',
    'http-version', 'response-hrtime', 'status-code', 'req-headers', 'res-headers', 'incoming',
    'req_id'
]

INDENT = "  "

# This takes log entries from Bunyan, and pretty prints them to the console.
#
class BunyanDebugStream extends Writable
    #
    # * `options.colors` is a hash where keys are Bunyan log levels (e.g. `bunyan.DEBUG`) and values
    #   are an array of colors (e.g. `['magenta', 'bold']`.)  Uses the `colors` module to apply
    #   all colors to the message before logging.  You can also set `options.colors` to `false`
    #   to disable colors.
    # * `options.basepath` is the absolute path of the root of your project.  If you're creating
    #   this `BunyanDebugStream` from a file called `app.js` in the root of your project, then
    #   this should be `__dirname`.
    # * `options.basepathReplacement` is a string to replace `options.basepath` with in filenames.
    #   Defaults to '.'.
    # * `options.showProcess` if true then will show "processName loggerName[pid]" in the output.
    #   If false (the default) then this will just be "loggerName[pid]".
    # * `options.processName` is the name of this process.  Defaults to the filename of the second
    #   argument in `process.argv` (on the assumption that you're running something like
    #   `node myApp.js`.)
    # * `options.maxExceptionLines` is the maximum number of lines to show in a stack trace.
    # * `options.stringifiers` is similar to Bunyan's serializers, but will be used to turn
    #   properties in log entries into strings.  A `null` stringifier can be used to hide a
    #   property from the logs.
    # * `options.prefixers` is similar to `options.stringifiers` but these strings will be prefixed
    #   onto the beginning of the `msg`, and wrapped in "[]".
    # * `options.out` is the stream to write data to.  Defaults to `process.stdout`.
    #
    constructor: (@options={}) ->
        super {objectMode: true}

        # Compile color options
        @_colors = {}
        # Parse any options
        if ('colors' of @options) and !@options.colors
            # B&W for us.
            @_useColor = false
            for levelValue, level of LEVELS
                    @_colors[levelValue] = []
        else
            @_useColor = true

            # Load up the default colors
            for levelValue, level of LEVELS
                @_colors[levelValue] = level.colors

            # Add in any colors from the options.
            for level, c of (@options.colors ? {})
                if isString c then c = [c]
                if @_colors[level]?
                    @_colors[level] = c
                else
                    levelName = level
                    level = bunyan[levelName?.toUpperCase()]
                    if @_colors[level]?
                        @_colors[level] = c
                    else
                        # I don't know what to do with this...

        @_processName = @options.processName ?
            ( if process.argv.length > 1 then path.basename(process.argv[1], path.extname(process.argv[1])) ) ?
            ( if process.argv.length > 0 then path.basename(process.argv[0], path.extname(process.argv[0])) ) ?
            ''

        self = this
        @_stringifiers = {
            req: exports.stdStringifiers.req
            err: exports.stdStringifiers.err
        }
        if @options.stringifiers?
            @_stringifiers[key] = value for key, value of @options.stringifiers

        # Initialize some defaults
        @_prefixers = @options.prefixers ? {}
        @_out = @options.out ? process.stdout
        @_basepath = @options.basepath ? process.cwd()

        @_showDate = @options.showDate ? true
        @_showLoggerName = @options.showLoggerName ? true
        @_showPid = @options.showPid ? true
        @_showLevel = @options.showLevel ? true

    # Runs a stringifier.
    # Appends any keys consumed to `consumed`.
    #
    # Returns `{value, message}`.  If the `stringifier` returns `repalceMessage = true`, then
    # `value` will be null and `message` will be the result of the stringifier.  Otherwise
    # `message` will be the `message` passed in, and `value` will be the result of the stringifier.
    #
    _runStringifier: (entry, key, stringifier, consumed, message) ->
        consumed[key] = true
        value = null
        newMessage = message

        try
            if !stringifier?
                # Null stringifier means we hide the value
            else
                result = stringifier(entry[key], {
                    entry,
                    useColor: @_useColor,
                    debugStream: this
                })
                if !result?
                    # Hide the value
                else if isString result
                    value = result
                else
                    consumed[key] = true for key in (result.consumed ? [])
                    if result.value?

                        if result.replaceMessage
                            newMessage = result.value
                            value = null
                        else
                            value = result.value

        catch err
            # Go back to the original message
            newMessage = message
            value = "Error running stringifier:\n" + err.stack

        # Indent the result correctly
        if value?
            value = value.replace /\n/g, "\n#{INDENT}"

        return {message: newMessage, value}

    _entryToString: (entry) ->
        if typeof(entry) is 'string' then entry = JSON.parse(entry)

        colorsToApply = @_colors[entry.level ? bunyan.INFO]

        # src is the filename/line number
        src = srcToString entry.src, @_basepath, @options.basepathReplacement
        if src then src += ': '

        message = entry.msg

        consumed = {}
        consumed[field] = true for field in FIELDS_TO_IGNORE

        # Run our stringifiers
        values = []
        for key, stringifier of @_stringifiers
            if entry[key]?
                {message, value} = message = @_runStringifier(entry, key, stringifier, consumed, message)
                values.push "#{INDENT}#{key}: #{value}" if value?
            else
                consumed[key] = true

        # Run our prefixers
        prefixes = []
        for key, prefixer of @_prefixers
            if entry[key]?
                {message, value} = @_runStringifier(entry, key, prefixer, consumed, message)
                prefixes.push value if value?
            else
                consumed[key] = true

        # Use JSON.stringify on whatever is left
        for key, value of entry
            # Skip fields we don't care about
            if consumed[key] then continue

            valueString = JSON.stringify value
            if valueString?
                # Make sure value isn't too long.
                cols = process.stdout.columns
                start = "#{INDENT}#{key}: "
                if cols and (valueString.length + start.length) >= cols
                    valueString = valueString[0...(cols - 3 - start.length)] + "..."
                values.push "#{start}#{valueString}"

        prefixes = if prefixes.length > 0 then "[#{prefixes.join(',')}] " else ''

        date = if @_showDate then "#{dateToString entry.time ? new Date()} " else ''
        processStr = ""
        if @options.showProcess  then processStr += @_processName
        if @_showLoggerName      then processStr += entry.name
        if @_showPid             then processStr += "[#{entry.pid}]"
        if processStr.length > 0 then processStr += " "
        levelPrefix = if @_showLevel then (LEVELS[entry.level]?.prefix ? '      ') + ' ' else ''

        line = "
            #{date}#{processStr}#{levelPrefix}#{src}#{prefixes}#{applyColors message, colorsToApply}
        "

        line += "\n#{INDENT}#{request}" if request?
        line += "\n" + applyColors(values.join('\n'), colorsToApply) if values.length > 0
        return line

    _write: (entry, encoding, done) ->
        @_out.write @_entryToString(entry) + "\n"
        done()

module.exports = exports = (options) ->
    return new BunyanDebugStream options

# Build our custom versions of the standard Bunyan serializers.
serializers = module.exports.serializers = {}

for serializerName, serializer of bunyan.stdSerializers
    serializers[serializerName] = serializer

serializers.req = (req) ->
    answer = bunyan.stdSerializers.req(req)
    if answer?
        if req.user?
            answer.user = req?.user
    return answer

serializers.res = (res) ->
    answer = bunyan.stdSerializers.res(res)
    if answer?
        answer.headers = res._headers
        if res.responseTime?
            answer.responseTime = res.responseTime
    return answer

exports.stdStringifiers = {
    req: (req, {entry, useColor}) ->
        consumed = ['req', 'res']
        res = entry.res

        if entry['status-code']? and entry['method']? and entry['url']? and entry['res-headers']?
            # This is an entry from express-bunyan-logger.  Add all the fields to `consumed`
            # so we don't print them out.
            consumed = consumed.concat EXPRESS_BUNYAN_LOGGER_FIELDS

        # Get the statusCode
        statusCode = res?.statusCode ? entry['status-code']
        if statusCode?
            status = "#{statusCode}"
            if useColor
                statusColor = if statusCode < 200 then colors.grey \
                    else if statusCode < 400 then colors.green \
                    else colors.red
                status = colors.bold(statusColor(status))
        else
            status = ""

        # Get the response time
        responseTime = if res?.responseTime? then res.responseTime \
            else if entry.duration?
                # bunyan-middleware stores response time in 'duration'
                consumed.push 'duration'
                entry.duration
            else if entry["response-time"]?
                # express-bunyan-logger stores response time in 'response-time'
                consumed.push "response-time"
                entry["response-time"]
            else
                null
        if responseTime?
            responseTime = "#{responseTime}ms"
        else
            responseTime = ""

        # Get the user
        user = if req.user?
            "#{req.user?.username ? req.user?.name ? req.user}@"
        else if entry.user?
            consumed.push "user"
            "#{entry.user?.username ? entry.user?.name ? entry.user}@"
        else
            ""

        # Get the content length
        contentLength = res?.headers?['content-length'] ? entry['res-headers']?['content-length']
        contentLength = if contentLength? then "- #{contentLength} bytes" else ""

        host = req.headers?.host or null
        url = if host? then "#{host}#{req.url}" else "#{req.url}"

        fields = [req.method, user + url, status, responseTime, contentLength]
        fields = fields.filter (f) -> !!f
        request = fields.join ' '

        # If there's no message, then replace the message with the request
        replaceMessage = !entry.msg or
            entry.msg is 'request finish' # bunyan-middleware

        return {consumed, value: request, replaceMessage}

    err: (err, {useColor, debugStream}) ->
        return exceptionFormatter err, {
            format: if useColor then 'ansi' else 'ascii'
            colors: false # TODO ?
            maxLines: debugStream.options?.maxExceptionLines ? null
            basepath: debugStream._basepath
            basepathReplacement: debugStream.options?.basepathReplacement
        }


}

path = require 'path'
bunyan = require 'bunyan'
colors = require 'colors/safe'

endsWith = (str, suffix) -> str[-suffix.length..] is suffix

exports.lpad = lpad = (str, count, fill=' ') ->
    str = "" + str
    str = fill + str while str.length < count
    return str

# Convert a `date` into a syslog style "Nov 6 10:30:21".
exports.dateToString = do ->
    MONTHS = [
        'Jan', 'Feb', 'Mar', 'Apr',
        'May', 'Jun', 'Jul', 'Aug',
        'Sep', 'Oct', 'Nov', 'Dec'
    ]

    return (date) ->
        if(!date)
            return date
        else if(date instanceof Date)
            time = [
                (lpad date.getHours(),   2, '0'),
                (lpad date.getMinutes(), 2, '0'),
                (lpad date.getSeconds(), 2, '0')
            ].join ':'

            return [MONTHS[date.getMonth()], date.getDate(), time].join ' '
        else
            return '' + date

# Applies one or more colors to a message, and returns the colorized message.
applyColors = exports.applyColors = (message, colorList) ->
    return message if !message?

    for color in colorList
        message = colors[color](message)

    return message

# Transforms "/src/foo/bar.coffee" to "/s/f/bar".
# Transforms "/src/foo/index.coffee" to "/s/foo/".
toShortFilename = exports.toShortFilename = (filename, basepath=null, replacement="./") ->
    if basepath?
        if exports.isString(basepath) and !endsWith(basepath, path.sep) then basepath += path.sep
        filename = filename.replace basepath, replacement

    parts = filename.split path.sep

    file  = parts[parts.length - 1]
    ext   = path.extname file
    file  = path.basename file, ext

    if file is 'index'
        shortenIndex = parts.length - 3
        file = ''
    else
        shortenIndex = parts.length - 2

    # Strip the extension
    parts[parts.length - 1] = file
    for part, index in parts
        if index <= shortenIndex then parts[index] = parts[index][0]

    return parts.join '/'

# Transforms a bunyan `src` object (a `{file, line, func}` object) into a human readable string.
exports.srcToString = (src, basepath=null, replacement="./") ->
    if !src? then return ''

    file = (if src.file? then toShortFilename(src.file, basepath, replacement) else '') +
        (if src.line? then ":#{src.line}" else '')

    answer = if src.func? and file
        "#{src.func} (#{file})"
    else if src.func?
        src.func
    else if file
        file
    else
        ''

    return answer

EXPRESS_BUNYAN_LOGGER_FIELDS = ['remote-address', 'ip', 'method', 'url', 'referer', 'user-agent',
    'body', 'short-body', 'http-version', 'response-time', 'status-code', 'req-headers',
    'res-headers', 'incoming']

# Borrowed from lodash
exports.isString = (value) ->
    typeof value is 'string' or
        value and typeof value is 'object' and toString.call(value) is '[object String]' or
        false

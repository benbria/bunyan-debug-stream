{expect} = require 'chai'
bunyanDebugStream = require '../src/bunyanDebugStream'

describe 'Tests with stringifiers', ->
    it 'should work with a prefixer', ->
        stream = bunyanDebugStream {
            prefixers:
                account: (account) -> account?.name
            colors: false, showDate: false, showLevel: false, showLoggerName: false, showPid: false
        }

        # Should work for an account
        expect(stream._entryToString({account: {name: "hello"}, msg: "world"}))
        .to.equal "[hello] world"

        # Should work if the account is missing
        expect(stream._entryToString({account: null, msg: "world"}))
        .to.equal "world"

    it 'should hide fields if the prefixer returns null', ->
        stream = bunyanDebugStream {
            prefixers:
                account: (account) -> null
            colors: false, showDate: false, showLevel: false, showLoggerName: false, showPid: false
        }

        expect(stream._entryToString({account: {name: "hello"}, msg: "world"}))
        .to.equal "world"

    it 'should hide fields for a null prefixer', ->
        stream = bunyanDebugStream {
            prefixers:
                account: null
            colors: false, showDate: false, showLevel: false, showLoggerName: false, showPid: false
        }

        expect(stream._entryToString({account: {name: "hello"}, msg: "world"}))
        .to.equal "world"

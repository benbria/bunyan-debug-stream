{expect} = require 'chai'
bunyanDebugStream = require '../src/BunyanDebugStream'

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

    describe 'req stringifier', ->
        it 'should work', ->
            entry = {
                req:
                    headers:
                        host: 'foo.com'
                    method: 'GET'
                    url: "/index.html"
                    user:
                        name: 'dave'
                res:
                    headers:
                        "content-length": 500
                    responseTime: 100
                    statusCode: 404
            }

            {consumed, value, replaceMessage} = bunyanDebugStream.stdStringifiers.req entry.req, {entry, useColor: false}

            expect(value).to.equal 'GET dave@foo.com/index.html 404 100ms - 500 bytes'
            expect('req' in consumed).to.be.true
            expect(replaceMessage, "replaceMessage").to.be.true

        it 'should hide all the variables in a bunyan-express-logger req', ->
            entry = {
                "method": 'GET'
                "status-code": 200
                "url": '/index.html'
                "res-headers": []
                "req": {
                    headers: {
                        host: 'foo.com'
                    }
                    method: 'GET'
                    url: "/index.html"
                }
                msg: 'hello'
            }

            {consumed, value, replaceMessage} = bunyanDebugStream.stdStringifiers.req entry.req, {entry, useColor: false}

            expect(value).to.equal 'GET foo.com/index.html 200'
            expect('req' in consumed).to.be.true
            expect('body' in consumed).to.be.true
            expect(replaceMessage, "replaceMessage").to.be.false

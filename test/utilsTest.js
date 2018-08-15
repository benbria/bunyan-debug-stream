const { expect } = require('chai');
const { dateToString, lpad } = require('../src/utils');

describe('utils', function() {
    it('should correctly format a date', function() {
        const date = new Date(1534345316112);
        const str = dateToString(date);

        // Need to compute this, as it depends what timezone we're in.
        const hours = lpad(date.getHours(), 2, '0');
        const minutes = lpad(date.getMinutes(), 2, '0');
        const seconds = lpad(date.getSeconds(), 2, '0');

        expect(str).to.equal(`Aug 15 ${hours}:${minutes}:${seconds}`);
    });

    it('should correctly format a date which is not a date', function() {
        const date = 'hello';
        const str = dateToString(date);
        expect(str).to.equal('hello');
    });

});
let acorn = require('acorn')
let assert = require('assert')

let preprocessModule = require('../dist/index').preprocessModule

describe('preprocessModule', () => {
  it('returns correct output with <import>', () => {
    let code =`
      import a from 'a';
      a.member(function () {});
    `;
    let expectedOutput = `
      import a from 'a';
      (function () {
      });
    `;

    let output = preprocessModule('unknown.js', {}, code, {
      library: 'a',
      call: 'member'
    });

    assert.equal(
      expectedOutput.replace(/\s+/g, ''),
      output.replace(/\s+/g, '')
    )
  })

  it('returns correct output with <require>', () => {
    let code =`
      let a = require('a');
      a.member(function () {});
    `;

    let expectedOutput = `
      let a = require('a');
      (function () {
      });
    `;

    let output = preprocessModule('unknown.js', {}, code, {
      library: 'a',
      call: 'member'
    });

    assert.equal(
      expectedOutput.replace(/\s+/g, ''),
      output.replace(/\s+/g, '')
    );
  })
})

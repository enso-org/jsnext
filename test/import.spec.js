let acorn = require('acorn')
let assert = require('assert')

let getAndRemoveLibImports = require('../dist/index').getAndRemoveLibImports
let getLibModuleRefs = require('../dist/index').getLibModuleRefs

describe('getAndRemoveLibImports', () => {
  it('parses <import> expression', () => {
    let parser = getParser("import a from 'b'");
    let ast = parser.parse();

    let imports = getAndRemoveLibImports(ast, 'b');
    let module = imports[0].specifiers[0].local.name;
    assert.equal(module, 'a');
  })

  it('parses <require> expression', () => {
    let parser = getParser("let a = require('b')");
    let ast = parser.parse();

    let imports = getAndRemoveLibImports(ast, 'b');
    let module = imports[0].id.name;
    assert.equal(module, 'a');
  })
})

describe('getLibModuleRefs', () => {
  it('parses <import> expression', () => {
    let parser = getParser("import a from 'b'");
    let ast = parser.parse();

    let imports = getLibModuleRefs(ast, 'b');
    assert.deepEqual(imports, ['a']);
  })

  it('parses <require> expression', () => {
    let parser = getParser("let a = require('b')");
    let ast = parser.parse();

    let imports = getLibModuleRefs(ast, 'b');
    assert.deepEqual(imports, ['a']);
  })
})

function getParser(code) {
  let parser = new acorn.Parser({
    ecmaVersion: 9,
    sourceType: 'module',
    locations: true,
    sourceFile: 'unknown.js'
  }, code)
  return parser;
}


acorn     = require 'acorn'
walk      = require 'acorn/dist/walk'
escodegen = require 'escodegen'


libName = '@luna-lang/jsnext'


#################
### AST Utils ###
#################

types =
  arrayExpression         : 'ArrayExpression'
  arrowFunctionExpression : 'ArrowFunctionExpression'
  blockStatement          : 'BlockStatement'
  callExpression          : 'CallExpression'
  functionDeclaration     : 'FunctionDeclaration'
  identifier              : 'Identifier'
  importDeclaration       : 'ImportDeclaration'
  literal                 : 'Literal'
  memberExpression        : 'MemberExpression'
  program                 : 'Program'

memberExpression = (parser, base, prop) ->
  node          = new acorn.Node parser
  node.type     = 'MemberExpression'
  node.object   = base
  node.property = prop
  node

identifier = (parser, name, cfg) ->
  node      = new acorn.Node parser
  node.type = 'Identifier'
  node.name = name
  node.loc  = cfg.loc
  node

callExpression = (parser, callee, args, cfg) ->
  node           = new acorn.Node parser
  node.type      = 'CallExpression'
  node.callee    = callee
  node.arguments = args
  node.loc       = cfg.loc
  node

expressionStatement = (parser, expression) ->
  node            = new acorn.Node parser
  node.type       = 'ExpressionStatement'
  node.expression = expression

arrowFunctionExpression = (parser, params, body, cfg) ->
  node            = new acorn.Node parser
  node.type       = 'ArrowFunctionExpression'
  node.params     = params
  node.body       = body
  node.expression = false
  node.generator  = false
  node.loc        = cfg.loc
  node

blockStatement = (parser, body) ->
  node      = new acorn.Node parser
  node.type = 'BlockStatement'
  node.body = body
  node

returnStatement = (parser, argument) ->
  node          = new acorn.Node parser
  node.type     = 'ReturnStatement'
  node.argument = argument
  node


exports.isIdentifier = isIdentifier = (ast) -> ast.type == types.identifier
exports.isIdentifierNamed = isIdentifierNamed = (name, ast) -> (isIdentifier ast) && (ast.name == name)


replace = (parent, oldVal, newVal) ->
  for k,v of parent
    if (v == oldVal)
      parent[k] = newVal
      return
    else if v instanceof Array
      for el,i in v
        if el == oldVal
          v[i] = newVal
          return
  throw 'Insufficient pattern match.'

remove = (parent, oldVal) ->
  for k,v of parent
    if (v == oldVal)
      throw 'Cannot remove non-optional value'
    else if v instanceof Array
      for el,i in v
        if el == oldVal
          v.splice(i,1)
          return
  throw 'Insufficient pattern match.'


exports.getFunctionLike = getFunctionLike = (ast) ->
  if (ast.type == types.blockStatement) && (ast.expression.type == types.arrowFunctionExpression)
    return ast.expression
  else if (ast.type == types.functionDeclaration)
    return ast
  else return null

exports.getImports = getImports = (ast) ->
  imports = []
  walk.ancestor ast,
    ImportDeclaration: (node, ancestors) ->
      imports.push node
  return imports

exports.getAndRemoveLibImports = getAndRemoveLibImports = (ast, modName) ->
  imports = []
  walk.ancestor ast,
    ImportDeclaration: (node, ancestors) ->
      if node.source.value == modName
        imports.push node
        parent = getWalkParent ancestors
        remove parent, node
  return imports


# Reads str expression or gets all str expressions from list
readStrOrListOfStr = (ast) ->
  out = []
  if ast.type == types.literal
    out.push ast.value
  else if ast.type == types.arrayExpression
    for el in ast.elements
      if el.type == types.literal
        out.push el.value
  out



###################
### AST walking ###
###################

exports.getWalkParent = getWalkParent = (ancestors) -> ancestors[ancestors.length - 2]
exports.getParent = getParent     = (ancestors) -> ancestors[ancestors.length - 1]



#########################
### Module processing ###
#########################

# Get references to all local variables refering to this library
exports.getLibModuleRefs = getLibModuleRefs = (ast, modName) ->
  imports = getAndRemoveLibImports ast, modName
  imp.specifiers[0].local.name for imp in imports

# Walks AST and executes `f` on every expression like `jsnext.apply ...`
walkLibApply = (libRefs, ast, callName, f) ->
  walk.ancestor ast,
    MemberExpression: (node, ancestors) ->
      if (isIdentifier node.object) && (node.object.name in libRefs)
        if isIdentifierNamed callName, node.property
          parent = getWalkParent ancestors
          f parent, ancestors.slice(0,-2)


exports.preprocessModule = preprocessModule = (fileName, extensionMap, code, cfg={}) ->
  changed     = false
  parser      = new acorn.Parser {ecmaVersion: 9, sourceType: 'module', locations:true, sourceFile:fileName}, code
  ast         = parser.parse()
  modName     = cfg.library     || libName
  callName    = cfg.call        || 'apply'
  defaultExts = cfg.defaultExts || []
  libRefs     = getLibModuleRefs ast, modName
  walkLibApply libRefs, ast, callName, (node, ancestors) ->
    changed = true
    if node.type == types.callExpression
      switch node.arguments.length
        when 2
          extensions = defaultExts.concat (readStrOrListOfStr node.arguments[0])
          localAst   = node.arguments[1]
        when 1
          extensions = defaultExts
          localAst   = node.arguments[0]
        else throw 'Unsupported AST shape.'

      localAncestors = ancestors.slice()
      localAncestors.push node
      for ext in extensions
        fexts = extensionMap[ext]
        if fexts? then for fext in fexts
          fext parser, localAst, localAncestors
    parent = getParent ancestors
    replace parent, node, localAst
  gen = escodegen.generate ast,
    sourceMap: true
    sourceMapWithCode: true
  if changed then return gen.code else return code



###################################
### Example AST transformations ###
###################################


# Overload operators according to rules
# >> overloadOperators (opname) => "operator" + opname
# converts `a + b` to `operator+(a,b)`
exports.overloadOperators = overloadOperators = (f) => (parser, ast, ancestors) =>
  handleExpr = (node, ancestors, name, nexpr) =>
    parent = getWalkParent ancestors
    name   = f name
    if name
      prop = identifier parser, name, {loc: node.loc}
      call = callExpression parser, prop, nexpr, {loc: node.loc}
      replace parent, node, call

  walk.ancestor ast,
    UnaryExpression  : (node, ancestors) => handleExpr node, ancestors, "prefix#{node.operator}"  , [node.argument]
    UpdateExpression : (node, ancestors) => handleExpr node, ancestors, "postfix#{node.operator}" , [node.argument]
    BinaryExpression : (node, ancestors) => handleExpr node, ancestors, node.operator             , [node.left, node.right]


# Overload if ... then ... else ... expression
# >> overloadIfThenElse 'ite'
# converts `if (a == b) {f = 1} else {f = 2}` to `ite (a == b) (() => {f = 1}) (() => {f = 2})`
exports.overloadIfThenElse = overloadIfThenElse = (name) => (parser, ast, ancestors) =>
  walk.ancestor ast,
    IfStatement: (node, ancestors) =>
      parent = getWalkParent ancestors
      prop   = identifier parser, name, {loc: node.loc}
      body   = arrowFunctionExpression parser, [], node.consequent, {loc: node.consequent.loc}
      args   = [node.test, body]
      if node.alternate?
        alt = arrowFunctionExpression parser, [], node.alternate , {loc: node.alternate.loc}
        args.push alt
      call   = callExpression parser, prop, args, {loc: node.loc}
      replace parent, node, call


# Replace qualified accessors
# >> replaceQualifiedAccessors 'Math', 'X.Math'
# converts `Math.sin(a)` to `X.Math.sin(a)`
exports.replaceQualifiedAccessors = replaceQualifiedAccessors = (name, newName) => (parser, ast, ancestors) =>
  walk.ancestor ast,
    MemberExpression: (node, ancestors) =>
      if (node.object.type == types.identifier) && (node.object.name == name)
        node.object.name = newName


# Insert arbitrary code to header.
# WARNING: Unsafe! Run after all other passes, the code is handled as variable, so it produces invalid AST.
exports.insertHeader = insertHeader = (raw) => (parser, ast, ancestors) =>
  if ast.type == types.callExpression
    code = identifier parser, raw, {loc: ast.loc}
    ast.callee.body.body.unshift code

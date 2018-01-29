
import * as jsnext from 'jsnext'


export rulesExample =
  'mylib.math': [ jsnext.overloadOperators((n) => 'op'+n)
                , jsnext.overloadIfThenElse('ite')
                , jsnext.replaceQualifiedAccessors('Math', 'X.Math')
                ]



### Default config ###

txt = '''
import * as pkg1   from 'pkg1'
import * as jsnext from '@luna-lang/jsnext'

foo = jsnext.apply(['mylib.math'], (function() {
  if(t){a+Math.sin(b)};
})());

bar = jsnext.apply([], (function() {
  if(t){a+Math.sin(b)};
})());

'''

out = jsnext.preprocessModule 'index.js', rulesExample, txt
console.log '----------'
console.log out



### Custom config ###

txt = '''
import * as pkg1  from 'pkg1'
import * as mylib from 'mylib'

foo = mylib.expr((function() {
  if(t){a+Math.sin(b)};
})());

bar = mylib.expr((function() {
  if(t){a+Math.sin(b)};
})());

'''

out = jsnext.preprocessModule 'index.js', rulesExample, txt, {library: 'mylib', call: 'expr', defaultExts: ['mylib.math']}
console.log '----------'
console.log out

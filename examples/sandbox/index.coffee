
import * as jsnext from 'jsnext'


export rulesExample =
  'basegl.math': [ jsnext.overloadOperators((n) => 'op'+n)
                 , jsnext.overloadIfThenElse('ite')
                 , jsnext.replaceQualifiedAccessors('Math', 'X.Math')
                 ]


out = jsnext.preprocessModule 'index.js', rulesExample, '''
import * as jsnext from 'jsnext'

foo = jsnext.apply(['basegl.math'], (function() {
  if(t){a+Math.sin(b)};
})());

bar = jsnext.apply([], (function() {
  if(t){a+Math.sin(b)};
})());

'''

console.log out

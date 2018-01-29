var webpack = require('webpack');
const UglifyJsPlugin = webpack.optimize.UglifyJsPlugin;
const path = require('path');

const env    = require('yargs').argv.env;

let project = env;


let libraryName = 'bundle';
let libPath     = path.resolve(__dirname, '..', 'dist')

let plugins = [];
let outputFile;

if (env === 'build') {
  plugins.push(new UglifyJsPlugin({ minimize: true }));
  outputFile = libraryName + '.min.js';
} else {
  outputFile = libraryName + '.js';
}

module.exports =
  { entry: path.resolve(__dirname, project, 'index.coffee')
  , context: libPath
  , output:
    { path: path.resolve(__dirname, project, 'dist')
    , filename: outputFile
    , library: libraryName
    , strictModuleExceptionHandling: true
    , libraryTarget: 'umd'
    , umdNamedDefine: true
    }
  , node:
    { __filename: true
    , __dirname: true
    }
  , devtool: "eval-source-map"
  , devServer: { contentBase: path.resolve(__dirname, project, 'dist') }
  , resolve:
    { extensions: ['.js', '.coffee']
    , modules:
      [ libPath
      , "node_modules"
      ]
    , alias:
      { 'jsnext': libPath
  	  }
    }
  , module:
    { strictExportPresence: true
    , rules:
      [ { use: 'coffee-loader'  , test: /\.(coffee)$/                                   }
      , { use: 'raw-loader'     , test: /\.(glsl|vert|frag)$/ , exclude: /node_modules/ }
      , { use: 'glslify-loader' , test: /\.(glsl|vert|frag)$/ , exclude: /node_modules/ }
      ]
    }
  , plugins:[]

};

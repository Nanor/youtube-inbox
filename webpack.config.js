webpack = require('webpack')

module.exports = {
    entry: './src/main.coffee',
    output: {
        path: __dirname + '/out',
        filename: 'bundle.js'
    },
    module: {
        loaders: [
            { test: /\.css/, loader: 'style!css'},
            { test: /\.sass/, loader: 'style!css!sass?indentedSyntax'},
            { test: /\.coffee$/, loader: "coffee-loader" },
            { test: /\.(coffee\.md|litcoffee)$/, loader: "coffee-loader?literate" },
            { test: /\.woff(2)?(\?v=[0-9]\.[0-9]\.[0-9])?$/, loader: "url-loader?limit=10000&minetype=application/font-woff" },
            { test: /\.(ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/, loader: "file-loader" }
        ]
    },
    plugins: [
        new webpack.optimize.UglifyJsPlugin({minimize: true})
    ]
};
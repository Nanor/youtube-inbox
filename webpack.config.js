module.exports = {
    entry: [
        './src/index.html',
        './src/main.coffee',
        './src/main.sass',
        './src/favicon-vflz7uhzw.ico',
        'font-awesome-webpack'
    ],
    output: {
        path: __dirname + '/out',
        filename: 'bundle.js'
    },
    module: {
        loaders: [
            { test: /\.sass$/, loader: 'style!css!sass?indentedSyntax'},
            { test: /\.coffee$/, loader: 'coffee-loader' },
            { test: /\.(html|ico|woff2?|ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/, loader: 'file-loader?name=[name].[ext]' },
        ]
    }
};
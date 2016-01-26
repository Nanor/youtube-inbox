module.exports = {
    entry: [
        './src/index.html',
        './src/main.coffee',
        './src/main.sass',
        './src/favicon-32.ico',
        'font-awesome-webpack',
        './node_modules/bootstrap/dist/css/bootstrap.min.css',
        './node_modules/bootstrap/dist/css/bootstrap-theme.min.css'
    ],
    output: {
        path: __dirname + '/out',
        filename: 'bundle.js'
    },
    module: {
        loaders: [
            { test: /\.jade$/, loader: 'jade-loader' },
            { test: /\.sass$/, loader: 'style!css!sass?indentedSyntax'},
            { test: /\.css$/, loader: 'style!css'},
            { test: /\.coffee$/, loader: 'coffee-loader' },
            { test: /\.(html|ico|woff2?|ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/, loader: 'file-loader?name=[name].[ext]' },
        ]
    }
};
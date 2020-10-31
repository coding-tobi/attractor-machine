const path = require("path");
const HtmlWebpackPlugin = require("html-webpack-plugin");

module.exports = {
  entry: "./index.js",
  mode: "development",
  devtool: "inline-source-map",
  devServer: {
    contentBase: path.join(__dirname, "public"),
    compress: true,
    port: 9000,
  },
  module: {
    rules: [
      {
        test: /\.ts$/i,
        use: "ts-loader",
        exclude: /node_modules/,
      },
      {
        test: /\.elm$/i,
        exclude: [/elm-stuff/, /node_modules/],
        use: {
          loader: "elm-webpack-loader",
          options: {
            cwd: path.resolve(__dirname, "elm"),
            optimize: false,
          },
        },
      },
      {
        test: /\.css$/i,
        use: ["raw-loader", "extract-loader", "css-loader"],
      },
    ],
  },
  resolve: {
    extensions: [".ts", ".js"],
  },
  plugins: [
    new HtmlWebpackPlugin({
      inject: false,
      template: require("html-webpack-template"),
      title: "attractor",
      lang: "de",
      baseHref: "/",
      mobile: true,
      bodyHtmlSnippet: "<attractor-machine></attractor-machine>",
    }),
  ],
  output: {
    filename: "[name].[contenthash].js",
  },
};

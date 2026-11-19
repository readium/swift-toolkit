const path = require("path");
const CopyPlugin = require("copy-webpack-plugin");

module.exports = {
  mode: "production",
  devtool: "source-map",
  // devtool: "eval-source-map",
  entry: {
    reflowable: "./src/index-reflowable.js",
    fixed: "./src/index-fixed.js",
    "fixed-wrapper-one": "./src/index-fixed-wrapper-one.js",
    "fixed-wrapper-two": "./src/index-fixed-wrapper-two.js",
  },
  output: {
    filename: "readium-[name].js",
    path: path.resolve(__dirname, "../Assets/Static/scripts"),
  },
  resolve: {
    extensions: [".ts", "..."],
  },
  plugins: [
    new CopyPlugin({
      patterns: [
        {
          from: path.resolve(__dirname, "node_modules/@readium/css/css/dist"),
          to: path.resolve(__dirname, "../Assets/Static/readium-css"),
          globOptions: {
            ignore: ["**/fonts/**"],
          },
        },
      ],
    }),
  ],
  module: {
    rules: [
      {
        test: /\.m?[jt]s$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
          options: {
            presets: ["@babel/preset-env", "@babel/preset-typescript"],
          },
        },
      },
    ],
  },
};

const path = require("path");

module.exports = {
  mode: "production",
  devtool: "source-map",
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
  module: {
    rules: [
      {
        test: /\.m?js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
          options: {
            presets: ["@babel/preset-env"],
          },
        },
      },
    ],
  },
};

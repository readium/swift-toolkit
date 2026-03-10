const path = require("path");
const CopyPlugin = require("copy-webpack-plugin");
const CleanCSS = require("clean-css");

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
  plugins: [
    new CopyPlugin({
      patterns: [
        {
          from: "node_modules/@readium/css/css/dist",
          to: "../readium-css",
          transform(content, path) {
            if (path.endsWith(".css") && process.env.MINIFY_CSS === "true") {
              return new CleanCSS({
                level: {
                  1: {
                    specialComments: 0,
                  },
                },
              }).minify(content).styles;
            }
            return content;
          },
        },
      ],
    }),
  ],
};

const path = require("path");
const CopyPlugin = require("copy-webpack-plugin");
const CleanCSS = require("clean-css");

module.exports = (env = {}) => {
  const shouldMinify =
    process.env.MINIFY_CSS === "true" ||
    process.env.MINIFY_CSS === "1" ||
    env.minify === true ||
    env.minify === "true";

  const cleanCSS = shouldMinify ? new CleanCSS() : null;

  return {
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
            transform(content, absoluteFrom) {
              if (shouldMinify && absoluteFrom.endsWith(".css")) {
                return cleanCSS.minify(content).styles;
              }
              return content;
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
};

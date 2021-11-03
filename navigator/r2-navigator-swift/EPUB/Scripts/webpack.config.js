const path = require("path");

module.exports = {
  mode: "development",
  devtool: "hidden-source-map",
  entry: {
    reflowable: "./src/index-reflowable.js",
    fixed: "./src/index-fixed.js",
    "fixed-wrapper": "./src/index-fixed-wrapper.js",
  },
  output: {
    filename: "readium-[name].js",
    path: path.resolve(__dirname, "../Assets/Static/scripts"),
  },
};

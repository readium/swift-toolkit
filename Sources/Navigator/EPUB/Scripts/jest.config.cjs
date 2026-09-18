module.exports = {
  transform: {
    "^.+\\.ts$": ["ts-jest", { tsconfig: "tsconfig.test.json" }],
  },
  testMatch: ["**/*.test.ts"],
  testEnvironment: "jsdom",
};

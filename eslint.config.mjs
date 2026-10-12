// ESLint flat config for ktogler (ESLint 9+)
export default [
  {
    files: ["contents/code/**/*.js"],
    languageOptions: {
      ecmaVersion: 2020,
      sourceType: "script",
      globals: {
        console: "readonly",
        readConfig: "readonly",
        readFile: "readonly",
        callDBus: "readonly",
        getenv: "readonly",
        workspace: "readonly",
        registerShortcut: "readonly",
      },
    },
    rules: {
      "no-undef": "error",
      "no-unused-vars": [
        "error",
        { args: "after-used", argsIgnorePattern: "^_" },
      ],
    },
  },
];

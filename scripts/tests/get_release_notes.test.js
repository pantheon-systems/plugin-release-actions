const test = require("node:test");
const assert = require("node:assert");

const expected = `* Set Counter to 1 [[34](https://github.com/pantheon-systems/plugin-pipeline-example/pull/34)]
* Set Counter to 2 [[36](https://github.com/pantheon-systems/plugin-pipeline-example/pull/36)]`;

[
  {
    name: "dev changelog",
    path: "./scripts/tests/fixtures/dev.md",
    expected,
  },
  {
    name: "release changelog",
    path: "./scripts/tests/fixtures/release.md",
    expected,
  },
].forEach(({ name, path, expected }) => {
  test(name, () => {
    process.argv[2] = path;
    const actual = require("../get_release_notes");
    assert.equal(actual, expected);
  });
});

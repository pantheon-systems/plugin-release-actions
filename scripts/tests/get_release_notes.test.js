"use strict";
import assert from "node:assert";
import test from "node:test";

const expected = `* Set Counter to 1 [[34](https://github.com/pantheon-systems/plugin-pipeline-example/pull/34)]
* Set Counter to 2 [[36](https://github.com/pantheon-systems/plugin-pipeline-example/pull/36)]`;

const cases = [
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
];

for (const { name, path, expected } of cases) {
  test(name, async () => {
    process.argv[2] = path;
    const actual = (await import("../get_release_notes.js")).default;
    assert.equal(actual, expected);
  });
}

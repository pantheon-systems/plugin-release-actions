"use strict";
import { readFileSync } from "fs";
import { resolve } from "path";


export default (() => {
  // get the args
  const [path] = process.argv.slice(2);
  // throw if necessary args are missing
  if (!path) {
    throw new Error("Please provide a path to the file to parse");
  }
  const filePath = resolve(process.cwd(), path);
  const fileContent = readFileSync(filePath, "utf8");
  /**
   * @see {@link https://regex101.com/r/TmzSYI/1} for the regex explanation
   */
  const regex =
    /(?=## Changelog$\n+(?=^#{3}\s[\s\d\.-\w]+(\([\w\d\s]+\))?$\n(?<notes>^[\w\d\W][^#]{3,}$\n)))/gm;
  const matches = fileContent.matchAll(regex);
  const [releaseNotes] = [...matches].map((match) => match.groups.notes.trim());
  console.log(releaseNotes);
  return releaseNotes;
})();

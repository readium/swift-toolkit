/**
 * Copyright 2025 Readium Foundation. All rights reserved.
 * Use of this source code is governed by the BSD-style license
 * available in the top-level LICENSE file of the project.
 *
 * This script can be used to convert the localized files from https://github.com/w3c/publ-a11y-display-guide-localizations
 * into other output formats for various platforms.
 */

const fs = require('fs');
const path = require('path');
const [inputFolder, outputFormat, outputFolder, keyPrefix = ''] = process.argv.slice(2);

/**
 * Ends the script with the given error message.
 */
function fail(message) {
    console.error(`Error: ${message}`);
    process.exit(1);
}

/**
 * Converter for Apple localized strings.
 */
function convertApple(lang, version, keys, keyPrefix, write) {
    let disclaimer = `DO NOT EDIT. File generated automatically from v${version} of the ${lang} JSON strings.`;

    let stringsOutput = `// ${disclaimer}\n\n`;
    for (const [key, value] of Object.entries(keys)) {
        stringsOutput += `"${keyPrefix}${key}" = "${value}";\n`;
    }
    let stringsFile = path.join(`Resources/${lang}.lproj`, 'W3CAccessibilityMetadataDisplayGuide.strings');
    write(stringsFile, stringsOutput);

    // Using the "base" language, we will generate a static list of string keys to validate them at compile time.
    if (lang == 'en-US') {
        writeSwiftExtensions(disclaimer, keys, keyPrefix, write);
    }
}

/**
 * Generates a static list of string keys to validate them at compile time.
 */
function writeSwiftExtensions(disclaimer, keys, keyPrefix, write) {
    let keysOutput = `//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

// ${disclaimer}\n\npublic extension AccessibilityDisplayString {\n`
    let keysList = Object.keys(keys)
        .filter((k) => !k.endsWith("-descriptive"))
        .map((k) => removeSuffix(k, "-compact"));
    for (const key of keysList) {
        keysOutput += `    static let ${convertKebabToCamelCase(key)}: Self = "${keyPrefix}${key}"\n`;
    }
    keysOutput += "}\n"
    write("Publication/Accessibility/AccessibilityDisplayString+Generated.swift", keysOutput);
}

const converters = {
    apple: convertApple
};

if (!inputFolder || !outputFormat || !outputFolder) {
    console.error('Usage: node convert.js <input-folder> <output-format> <output-folder> [key-prefix]');
    process.exit(1);
}

const langFolder = path.join(inputFolder, 'lang');
if (!fs.existsSync(langFolder)) {
    fail(`the specified input folder does not contain a 'lang' directory`);
}

const convert = converters[outputFormat];
if (!convert) {
    fail(`unrecognized output format: ${outputFormat}, try: ${Object.keys(converters).join(', ')}.`);
}

fs.readdir(langFolder, (err, langDirs) => {
    if (err) {
        fail(`reading directory: ${err.message}`);
    }

    langDirs.forEach(langDir => {
        const langDirPath = path.join(langFolder, langDir);

        fs.readdir(langDirPath, (err, files) => {
            if (err) {
                fail(`reading language directory ${langDir}: ${err.message}`);
            }

            files.forEach(file => {
                const filePath = path.join(langDirPath, file);
                if (path.extname(file) === '.json') {
                    fs.readFile(filePath, 'utf8', (err, data) => {
                        if (err) {
                            console.error(`Error reading file ${file}: ${err.message}`);
                            return;
                        }

                        try {
                            const jsonData = JSON.parse(data);
                            const version = jsonData["metadata"]["version"];
                            convert(langDir, version, parseJsonKeys(jsonData), keyPrefix, write);
                        } catch (err) {
                            fail(`parsing JSON from file ${file}: ${err.message}`);
                        }
                    });
                }
            });
        });
    });
});

/**
 * Writes the given content to the file path relative to the outputFolder provided in the CLI arguments.
 */
function write(relativePath, content) {
    const outputPath = path.join(outputFolder, relativePath);
    const outputDir = path.dirname(outputPath);

    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    fs.writeFile(outputPath, content, 'utf8', err => {
        if (err) {
            fail(`writing file ${outputPath}: ${err.message}`);
        } else {
            console.log(`Wrote ${outputPath}`);
        }
    });
}

/**
 * Collects the JSON translation keys.
 */
function parseJsonKeys(obj) {
    const keys = {};
    for (const key in obj) {
        if (key === 'metadata') continue; // Ignore the metadata key
        if (typeof obj[key] === 'object') {
            for (const subKey in obj[key]) {
                if (typeof obj[key][subKey] === 'object') {
                    for (const innerKey in obj[key][subKey]) {
                        const fullKey = `${subKey}-${innerKey}`;
                        keys[fullKey] = obj[key][subKey][innerKey];
                    }
                } else {
                    keys[subKey] = obj[key][subKey];
                }
            }
        }
    }
    return keys;
}

function convertKebabToCamelCase(string) {
    return string
        .split('-')
        .map((word, index) => {
            if (index === 0) {
                return word;
            }
            return word.charAt(0).toUpperCase() + word.slice(1);
        })
        .join('');
}

function removeSuffix(str, suffix) {
    if (str.endsWith(suffix)) {
        return str.slice(0, -suffix.length);
    }
    return str;
}
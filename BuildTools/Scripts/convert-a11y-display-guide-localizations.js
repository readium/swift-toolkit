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

/**
 * Converter for Apple localized strings.
 */
const AppleConverter = {
    convert: (disclaimer, keys) => {
        let output = `// ${disclaimer}\n`;
        for (const [key, value] of Object.entries(keys)) {
            output += `"${key}" = "${value}";\n`;
        }
        return output;
    },
    getOutputPath: (lang, filename) => {
        return path.join(`${lang}.lproj`, 'W3CAccessibilityMetadataDisplayGuide.strings');
    }
};

/**
 * Converter for Android strings.xml files.
 */
const AndroidConverter = {
    convert: (disclaimer, keys) => {
        let androidFormat = `<?xml version="1.0" encoding="utf-8"?>\n<!-- ${disclaimer} -->\n<resources>\n`;
        for (const [key, value] of Object.entries(keys)) {
            const sanitizedKey = key.replace(/-/g, '_');
            androidFormat += `    <string name="${sanitizedKey}">${value}</string>\n`;
        }
        androidFormat += '</resources>\n';
        return androidFormat;
    },
    getOutputPath: (lang, filename) => {
        return path.join(`values-${lang}`, 'w3c_a11y_meta_display_guide_strings.xml');
    }
};

const converters = {
    apple: AppleConverter,
    android: AndroidConverter
};

const [inputFolder, outputFormat, outputFolder, keyPrefix = ''] = process.argv.slice(2);

if (!inputFolder || !outputFormat || !outputFolder) {
    console.error('Usage: node convert.js <input-folder> <output-format> <output-folder> [key-prefix]');
    process.exit(1);
}

const langFolder = path.join(inputFolder, 'lang');
if (!fs.existsSync(langFolder)) {
    console.error(`The specified input folder does not contain a 'lang' directory.`);
    return;
}

const converter = converters[outputFormat];
if (!converter) {
    console.error(`Unrecognized output format: ${outputFormat}. Try: ${Object.keys(converters).join(', ')}.`);
    return;
}

fs.readdir(langFolder, (err, langDirs) => {
    if (err) {
        console.error(`Error reading directory: ${err.message}`);
        return;
    }

    langDirs.forEach(langDir => {
        const langDirPath = path.join(langFolder, langDir);

        fs.readdir(langDirPath, (err, files) => {
            if (err) {
                console.error(`Error reading language directory ${langDir}: ${err.message}`);
                return;
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
                            const disclaimer = `DO NOT EDIT. File generated automatically from v${version} of lang/${path.join(langDir, file)}`;
                            const convertedData = converter.convert(disclaimer, parseJsonKeys(jsonData, keyPrefix));

                            const filenameWithoutExt = path.basename(file, '.json');
                            const relativeOutputPath = converter.getOutputPath(langDir, filenameWithoutExt);
                            const outputPath = path.join(outputFolder, relativeOutputPath);
                            const outputDir = path.dirname(outputPath);

                            if (!fs.existsSync(outputDir)) {
                                fs.mkdirSync(outputDir, { recursive: true });
                            }

                            fs.writeFile(outputPath, convertedData, 'utf8', err => {
                                if (err) {
                                    console.error(`Error writing file ${outputPath}: ${err.message}`);
                                } else {
                                    console.log(`Wrote ${outputPath}`);
                                }
                            });
                        } catch (err) {
                            console.error(`Error parsing JSON from file ${file}: ${err.message}`);
                        }
                    });
                }
            });
        });
    });
});

/**
 * Collects the JSON translation keys.
 */
function parseJsonKeys(obj, keyPrefix = '') {
    const keys = {};
    for (const key in obj) {
        if (key === 'metadata') continue; // Ignore the metadata key
        if (typeof obj[key] === 'object') {
            for (const subKey in obj[key]) {
                if (typeof obj[key][subKey] === 'object') {
                    for (const innerKey in obj[key][subKey]) {
                        const fullKey = `${keyPrefix}${subKey}-${innerKey}`;
                        keys[fullKey] = obj[key][subKey][innerKey];
                    }
                } else {
                    const fullKey = `${keyPrefix}${subKey}`;
                    keys[fullKey] = obj[key][subKey];
                }
            }
        }
    }
    return keys;
}

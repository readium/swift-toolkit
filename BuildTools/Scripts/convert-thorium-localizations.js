/**
 * Copyright 2026 Readium Foundation. All rights reserved.
 * Use of this source code is governed by the BSD-style license
 * available in the top-level LICENSE file of the project.
 *
 * This script converts the localized files from https://github.com/edrlab/thorium-locales/
 * into Apple .strings format.
 */

const fs = require('fs');
const fsPromises = fs.promises;
const path = require('path');

/**
 * Configuration for a thorium-locales project.
 */
class LocaleConfig {
    /**
     * @param {string} folder - The folder name in thorium-locales
     * @param {string} stripPrefix - Prefix to strip from JSON keys
     * @param {string} outputPrefix - Prefix to add to output keys
     * @param {string} outputFolder - Output folder for .lproj directories
     * @param {string[]|null} [includePrefixes] - Optional prefixes to include (if null, include all)
     */
    constructor({ folder, stripPrefix, outputPrefix, outputFolder, includePrefixes = null }) {
        if (!folder || !stripPrefix || !outputPrefix || !outputFolder) {
            throw new Error('LocaleConfig requires folder, stripPrefix, outputPrefix, and outputFolder');
        }
        this.folder = folder;
        this.stripPrefix = stripPrefix;
        this.outputPrefix = outputPrefix;
        this.outputFolder = outputFolder;
        this.includePrefixes = includePrefixes;
    }
}

/**
 * Configuration for each thorium-locales project.
 * Add new projects here as needed.
 */
const PROJECTS = {
    lcp: new LocaleConfig({
        folder: 'lcp',
        stripPrefix: 'lcp.',
        outputPrefix: 'ReadiumLCP.',
        outputFolder: 'Sources/LCP/Resources',
        includePrefixes: ['lcp.dialog']
    })
};

/**
 * Languages to process from thorium-locales.
 * Only these languages will be included in the output.
 */
const LANGUAGES = ['en', 'fr', 'it'];

// Parse arguments
const args = process.argv.slice(2);
const [inputFolder, outputFormat, ...projectNames] = args;

// If no projects specified, process all configured projects
const projectsToProcess = projectNames.length > 0
    ? projectNames
    : Object.keys(PROJECTS);

/**
 * Ends the script with the given error message.
 */
function fail(message) {
    console.error(`Error: ${message}`);
    process.exit(1);
}

async function processLocales() {
    for (const projectName of projectsToProcess) {
        const config = PROJECTS[projectName];
        if (!config) {
            fail(`Unknown project: ${projectName}. Available: ${Object.keys(PROJECTS).join(', ')}`);
        }

        console.log(`\nProcessing project: ${projectName}`);

        const languageKeys = await loadLanguageKeys(inputFolder, config.folder);

        // Filter keys if includePrefixes is specified
        if (config.includePrefixes) {
            for (const [lang, keys] of languageKeys) {
                const filteredKeys = {};
                for (const [key, value] of Object.entries(keys)) {
                    // Check if key starts with any of the allowed prefixes
                    // Also handle plural keys by checking the base key (before @suffix)
                    const baseKey = getBaseKey(key);
                    if (config.includePrefixes.some(prefix => baseKey.startsWith(prefix))) {
                        filteredKeys[key] = value;
                    }
                }
                languageKeys.set(lang, filteredKeys);
            }
        }

        const placeholderMappings = buildPlaceholderMappings(languageKeys);

        const writeForProject = (relativePath, content) => {
            writeFile(config.outputFolder, relativePath, content);
        };

        for (const [lang, keys] of languageKeys) {
            convert(lang, keys, config, writeForProject, placeholderMappings);
        }
    }
}

processLocales().catch(err => fail(err.message));

/**
 * Converter for Apple localized strings.
 */
function convertApple(lang, keys, config, write, placeholderMappings) {
    const lproj = `${lang}.lproj`;
    // Store both original key (for mapping lookup) and prefixed key (for output)
    // Strip the configured prefix since the output prefix already indicates the context
    const allEntries = Object.entries(keys).map(([key, value]) =>
        [key, config.outputPrefix + stripKeyPrefix(key, config.stripPrefix), value]
    );

    // Generate Localizable.strings
    write(path.join(lproj, 'Localizable.strings'), generateAppleStrings(lang, allEntries, placeholderMappings));
}

/**
 * Generates an Apple .strings file content from a list of [originalKey, prefixedKey, value] entries.
 */
function generateAppleStrings(lang, entries, placeholderMappings) {
    const disclaimer = `DO NOT EDIT. File generated automatically from the ${lang} JSON strings of https://github.com/edrlab/thorium-locales/.`;
    let output = `// ${disclaimer}\n\n`;
    for (const [originalKey, prefixedKey, value] of entries) {
        // Use original key (without prefix) to look up placeholder mapping
        const baseKey = getBaseKey(originalKey);
        const mapping = placeholderMappings[originalKey] || placeholderMappings[baseKey] || {};
        const escapedValue = escapeForAppleStrings(value);
        const convertedValue = convertPlaceholders(escapedValue, mapping);
        output += `"${convertKebabToCamelCase(prefixedKey)}" = "${convertedValue}";\n`;
    }

    return output;
}

const converters = {
    apple: convertApple
};

if (!inputFolder || !outputFormat) {
    console.error('Usage: node convert-thorium-localizations.js <input-folder> <output-format> [project...]');
    console.error('');
    console.error('Arguments:');
    console.error('  input-folder    Path to the cloned thorium-locales repository');
    console.error('  output-format   Output format (apple)');
    console.error('  project         Optional project name(s) to process (default: all)');
    console.error('');
    console.error(`Available projects: ${Object.keys(PROJECTS).join(', ')}`);
    process.exit(1);
}

const convert = converters[outputFormat];
if (!convert) {
    fail(`unrecognized output format: ${outputFormat}, try: ${Object.keys(converters).join(', ')}.`);
}

/**
 * Loads all JSON locale files from the specified folder and returns a Map of language -> keys.
 */
async function loadLanguageKeys(inputFolder, localeFolder) {
    const languageKeys = new Map();
    const folderPath = path.join(inputFolder, localeFolder);

    if (!fs.existsSync(folderPath)) {
        fail(`the ${localeFolder} folder was not found at ${folderPath}`);
    }

    console.log(`Processing folder: ${localeFolder}`);

    const files = await fsPromises.readdir(folderPath);

    for (const file of files) {
        if (path.extname(file) !== '.json') continue;

        // Normalize locale to BCP 47 format (hyphens) to merge keys from
        // files like pt_PT.json and pt-PT.json into a single locale entry.
        const lang = path.basename(file, '.json').replace(/_/g, '-');

        // Skip languages not in the allowed list
        if (!LANGUAGES.includes(lang)) {
            continue;
        }

        const filePath = path.join(folderPath, file);

        try {
            const data = await fsPromises.readFile(filePath, 'utf8');
            const jsonData = JSON.parse(data);
            const keys = parseJsonKeys(jsonData);

            if (!languageKeys.has(lang)) {
                languageKeys.set(lang, {});
            }
            Object.assign(languageKeys.get(lang), keys);
        } catch (err) {
            fail(`processing ${file}: ${err.message}`);
        }
    }

    return languageKeys;
}

/**
 * Builds placeholder-to-position mappings from English keys.
 * This ensures consistent argument ordering across all languages.
 */
function buildPlaceholderMappings(languageKeys) {
    const placeholderMappings = {};
    const englishKeys = languageKeys.get('en');

    if (englishKeys) {
        for (const [key, value] of Object.entries(englishKeys)) {
            const mapping = extractPlaceholderMapping(value);
            if (Object.keys(mapping).length > 0) {
                // For pluralized keys (ending with @one, @other, etc.), use the base key for mapping
                const baseKey = getBaseKey(key);
                // Only set if not already set (first plural form encountered sets the mapping)
                if (!placeholderMappings[baseKey]) {
                    placeholderMappings[baseKey] = mapping;
                }
            }
        }
    }

    return placeholderMappings;
}

/**
 * Writes the given content to the file path relative to the specified base folder.
 */
function writeFile(baseFolder, relativePath, content) {
    const outputPath = path.join(baseFolder, relativePath);
    const outputDir = path.dirname(outputPath);

    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    fs.writeFileSync(outputPath, content, 'utf8');
    console.log(`Wrote ${outputPath}`);
}

/**
 * Strips the plural suffix from a key (e.g., @one, @other).
 */
function getBaseKey(key) {
    return key.replace(/@(zero|one|two|few|many|other)$/, '');
}

/**
 * Strips a prefix from a key.
 */
function stripKeyPrefix(key, prefix) {
    return key.startsWith(prefix) ? key.slice(prefix.length) : key;
}

/**
 * Recursively collects the JSON translation keys using dot notation and special handling for pluralization patterns.
 * Plural keys use flat format with underscore suffix (e.g., key_one, key_other) which are converted to @ suffix.
 */
function parseJsonKeys(obj, prefix = '') {
    const keys = {};
    const pluralSuffixes = ['_zero', '_one', '_two', '_few', '_many', '_other'];

    for (const [key, value] of Object.entries(obj)) {
        const fullKey = prefix ? `${prefix}.${key}` : key;

        if (typeof value === 'object' && value !== null) {
            // Recursively process nested objects
            Object.assign(keys, parseJsonKeys(value, fullKey));
        } else {
            // Check for plural suffix and convert underscore to @ notation
            const pluralSuffix = pluralSuffixes.find(suffix => fullKey.endsWith(suffix));
            if (pluralSuffix) {
                const baseKey = fullKey.slice(0, -pluralSuffix.length);
                const pluralForm = pluralSuffix.slice(1); // Remove leading underscore
                keys[`${baseKey}@${pluralForm}`] = value;
            } else {
                // Simple key-value pair
                keys[fullKey] = value;
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

/**
 * Extracts placeholders from a string and builds a mapping from placeholder name to position index.
 * Returns an object with placeholder names as keys and their positional index (1-based) as values.
 * Placeholders are assigned positions based on their order of appearance.
 */
function extractPlaceholderMapping(value) {
    const placeholderRegex = /\{\{\s*(\w+)\s*\}\}/g;
    const placeholders = [];
    let match;

    while ((match = placeholderRegex.exec(value)) !== null) {
        const name = match[1];
        if (!placeholders.includes(name)) {
            placeholders.push(name);
        }
    }

    if (placeholders.length === 0) {
        return {};
    }

    const mapping = {};
    let position = 1;
    for (const name of placeholders) {
        mapping[name] = position++;
    }

    return mapping;
}

/**
 * Escapes special characters for iOS .strings format.
 * Must be called before placeholder conversion.
 *
 * - \ -> \\
 * - " -> \"
 * - newlines -> \n
 * - % -> %%
 */
function escapeForAppleStrings(value) {
    return value
        // Escape backslashes first (before other escapes add more backslashes)
        .replace(/\\/g, '\\\\')
        // Escape double quotes
        .replace(/"/g, '\\"')
        // Escape newlines
        .replace(/\n/g, '\\n')
        // Escape literal % characters
        .replace(/%/g, '%%');
}

/**
 * Converts Mustache-style placeholders to iOS format specifiers using the provided mapping.
 * Placeholders become `%N$@` (string format) or `%N$d` (integer format) for `count`.
 * Using %d for `count` allows the GenerateLocalizedUserString.swift script to identify the
 * count offset to resolve the pluralization form.
 */
function convertPlaceholders(value, placeholderMap) {
    if (Object.keys(placeholderMap).length === 0) {
        return value;
    }

    return value.replace(/\{\{\s*(\w+)\s*\}\}/g, (match, name) => {
        const position = placeholderMap[name];
        if (position === undefined) {
            // Placeholder not in mapping, leave unchanged
            return match;
        }

        // Use %d for `count` placeholder, %@ for everything else
        const formatSpec = (name === 'count') ? 'd' : '@';
        return `%${position}$${formatSpec}`;
    });
}

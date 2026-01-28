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
const { generateAccessibilityDisplayStringExtensions } = require('./generate-a11y-extensions');

/**
 * Plural suffixes used in thorium-locales JSON files (underscore format).
 */
const PLURAL_SUFFIXES = ['_zero', '_one', '_two', '_few', '_many', '_other'];

/**
 * Languages to process from thorium-locales.
 */
const LANGUAGES = ['en', 'fr', 'it'];

/**
 * Represents a localization key with support for plural forms.
 */
class LocalizationKey {
    constructor(base, pluralForm = null) {
        this.base = base;
        this.pluralForm = pluralForm;
    }

    stripPrefix(prefix) {
        if (!prefix || !this.base.startsWith(prefix)) {
            return this;
        }
        return new LocalizationKey(this.base.slice(prefix.length), this.pluralForm);
    }

    toCamelCase() {
        const camel = this.base
            .split('-')
            .map((word, index) => (index === 0 ? word : word.charAt(0).toUpperCase() + word.slice(1)))
            .join('');
        return new LocalizationKey(camel, this.pluralForm);
    }

    matchesAnyPrefix(prefixes) {
        return prefixes.some(prefix => this.base.startsWith(prefix));
    }

    toString() {
        return this.base;
    }
}

/**
 * Represents a localization entry (key-value pair).
 */
class LocalizationEntry {
    constructor(key, value, sourceKey = null) {
        this.key = key;
        this.value = value;
        this.sourceKey = sourceKey;
        this._placeholders = null;
    }

    get placeholders() {
        if (this._placeholders === null) {
            const regex = /\{\{\s*(\w+)\s*\}\}/g;
            const found = [];
            let match;
            while ((match = regex.exec(this.value)) !== null) {
                if (!found.includes(match[1])) {
                    found.push(match[1]);
                }
            }
            this._placeholders = found;
        }
        return this._placeholders;
    }

    get hasPlaceholders() {
        return this.placeholders.length > 0;
    }
}

/**
 * Configuration for a thorium-locales project.
 */
class LocaleConfig {
    constructor({
        folder,
        stripPrefix = '',
        outputPrefix = '',
        outputFolder,
        includePrefixes = null,
        tableName = 'Localizable',
        keyTransform = null,
        postProcess = null,
        convertKeysToCamelCase = true
    }) {
        if (!folder || !outputFolder) {
            throw new Error('LocaleConfig requires folder and outputFolder');
        }
        this.folder = folder;
        this.stripPrefix = stripPrefix;
        this.outputPrefix = outputPrefix;
        this.outputFolder = outputFolder;
        this.includePrefixes = includePrefixes;
        this.tableName = tableName;
        this.keyTransform = keyTransform;
        this.postProcess = postProcess;
        this.convertKeysToCamelCase = convertKeysToCamelCase;
    }

    transformEntry(entry) {
        const sourceKey = entry.key;
        let base = sourceKey.base;

        if (this.stripPrefix && base.startsWith(this.stripPrefix)) {
            base = base.slice(this.stripPrefix.length);
        }
        if (this.keyTransform) {
            base = this.keyTransform(base);
        }
        if (this.outputPrefix) {
            base = this.outputPrefix + base;
        }

        const newKey = new LocalizationKey(base, sourceKey.pluralForm);
        return new LocalizationEntry(newKey, entry.value, sourceKey);
    }

    shouldInclude(entry) {
        if (!this.includePrefixes) {
            return true;
        }
        return entry.key.matchesAnyPrefix(this.includePrefixes);
    }
}

// ============================================================================
// Apple Strings Converter
// ============================================================================

/**
 * Converts localization entries to Apple .strings format.
 */
class AppleStringsConverter {
    constructor(referenceEntries) {
        this._placeholderMappings = this._buildPlaceholderMappings(referenceEntries);
    }

    /**
     * Generates .strings file content for the given entries.
     */
    generate(lang, entries, config) {
        const outputEntries = entries.map(entry => config.transformEntry(entry));

        const disclaimer = `DO NOT EDIT. File generated automatically from the ${lang} JSON strings of https://github.com/edrlab/thorium-locales/.`;
        let content = `// ${disclaimer}\n\n`;

        for (const entry of outputEntries) {
            content += this._formatEntry(entry, config.convertKeysToCamelCase) + '\n';
        }

        // Extract output keys for postProcess
        const outputKeys = outputEntries.map(entry =>
            this._formatKey(entry.key.stripPrefix(config.outputPrefix))
        );

        return { content, outputKeys };
    }

    _buildPlaceholderMappings(entries) {
        const mappings = new Map();
        for (const entry of entries) {
            if (!entry.hasPlaceholders) continue;
            const baseKey = entry.key.base;
            if (mappings.has(baseKey)) continue;

            const mapping = {};
            entry.placeholders.forEach((name, index) => {
                mapping[name] = index + 1;
            });
            mappings.set(baseKey, mapping);
        }
        return mappings;
    }

    _getPlaceholderMapping(key) {
        return this._placeholderMappings.get(key.base) || {};
    }

    _formatEntry(entry, convertToCamelCase) {
        const transformedKey = convertToCamelCase ? entry.key.toCamelCase() : entry.key;
        const outputKey = this._formatKey(transformedKey);
        const lookupKey = entry.sourceKey || entry.key;
        const mapping = this._getPlaceholderMapping(lookupKey);
        const escapedValue = this._escape(entry.value);
        const convertedValue = this._convertPlaceholders(escapedValue, mapping);
        return `"${outputKey}" = "${convertedValue}";`;
    }

    _formatKey(key) {
        if (key.pluralForm) {
            return `${key.base}@${key.pluralForm}`;
        }
        return key.base;
    }

    _escape(value) {
        return value
            .replace(/\\/g, '\\\\')
            .replace(/"/g, '\\"')
            .replace(/\n/g, '\\n')
            .replace(/%/g, '%%');
    }

    _convertPlaceholders(value, mapping) {
        if (Object.keys(mapping).length === 0) {
            return value;
        }
        return value.replace(/\{\{\s*(\w+)\s*\}\}/g, (match, name) => {
            const position = mapping[name];
            if (position === undefined) {
                return match;
            }
            const formatSpec = name === 'count' ? 'd' : '@';
            return `%${position}$${formatSpec}`;
        });
    }
}

// ============================================================================
// Utility Functions
// ============================================================================

function fail(message) {
    console.error(`Error: ${message}`);
    process.exit(1);
}

function writeFile(relativePath, content) {
    const outputDir = path.dirname(relativePath);

    try {
        fs.mkdirSync(outputDir, { recursive: true });
        fs.writeFileSync(relativePath, content, 'utf8');
        console.log(`Wrote ${relativePath}`);
    } catch (err) {
        fail(`Failed to write ${relativePath}: ${err.message}`);
    }
}

// ============================================================================
// JSON Parsing
// ============================================================================

function parseJsonEntries(obj, prefix = '') {
    const entries = [];

    for (const [key, value] of Object.entries(obj)) {
        const fullKey = prefix ? `${prefix}.${key}` : key;

        if (typeof value === 'string') {
            const pluralSuffix = PLURAL_SUFFIXES.find(suffix => fullKey.endsWith(suffix));
            if (pluralSuffix) {
                const baseKey = fullKey.slice(0, -pluralSuffix.length);
                const pluralForm = pluralSuffix.slice(1);
                entries.push(new LocalizationEntry(new LocalizationKey(baseKey, pluralForm), value));
            } else {
                entries.push(new LocalizationEntry(new LocalizationKey(fullKey), value));
            }
        } else if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
            entries.push(...parseJsonEntries(value, fullKey));
        } else {
            console.warn(`Warning: Skipping unexpected value type for key "${fullKey}": ${typeof value}`);
        }
    }

    return entries;
}

async function loadLanguageEntries(inputFolder, localeFolder) {
    const languageEntries = new Map();
    const folderPath = path.join(inputFolder, localeFolder);

    if (!fs.existsSync(folderPath)) {
        fail(`the ${localeFolder} folder was not found at ${folderPath}`);
    }

    console.log(`Processing folder: ${localeFolder}`);

    const files = await fsPromises.readdir(folderPath);

    for (const file of files) {
        if (path.extname(file) !== '.json') continue;

        const lang = path.basename(file, '.json').replace(/_/g, '-');
        if (!LANGUAGES.includes(lang)) continue;

        const filePath = path.join(folderPath, file);

        try {
            const data = await fsPromises.readFile(filePath, 'utf8');
            const jsonData = JSON.parse(data);
            const entries = parseJsonEntries(jsonData);

            if (!languageEntries.has(lang)) {
                languageEntries.set(lang, []);
            }
            languageEntries.get(lang).push(...entries);
        } catch (err) {
            fail(`processing ${file}: ${err.message}`);
        }
    }

    return languageEntries;
}

// ============================================================================
// Entry Point
// ============================================================================

const PROJECTS = {
    lcp: new LocaleConfig({
        folder: 'lcp',
        outputPrefix: 'readium.',
        outputFolder: 'Sources/LCP/Resources',
        includePrefixes: ['lcp.dialog']
    }),

    a11y: new LocaleConfig({
        folder: 'publication-metadata',
        stripPrefix: 'publication.metadata.accessibility.display-guide.',
        outputPrefix: 'readium.a11y.',
        outputFolder: 'Sources/Shared/Resources',
        includePrefixes: ['publication.metadata.accessibility.display-guide'],
        tableName: 'W3CAccessibilityMetadataDisplayGuide',
        keyTransform: key => key.replace(/\./g, '-'),
        convertKeysToCamelCase: false,
        postProcess: (lang, keys, config) => {
            if (lang === 'en') {
                generateAccessibilityDisplayStringExtensions(
                    keys,
                    'Sources/Shared/Publication/Accessibility/AccessibilityDisplayString+Generated.swift',
                    config.outputPrefix,
                    writeFile
                );
            }
        }
    })
};

const args = process.argv.slice(2);
const [inputFolder, ...projectNames] = args;

if (!inputFolder) {
    console.error('Usage: node convert-thorium-localizations.js <input-folder> [project...]');
    console.error('');
    console.error('Arguments:');
    console.error('  input-folder    Path to the cloned thorium-locales repository');
    console.error('  project         Optional project name(s) to process (default: all)');
    console.error('');
    console.error(`Available projects: ${Object.keys(PROJECTS).join(', ')}`);
    process.exit(1);
}

const projectsToProcess = projectNames.length > 0
    ? projectNames
    : Object.keys(PROJECTS);

async function processLocales(inputFolder, projectsToProcess) {
    for (const projectName of projectsToProcess) {
        const config = PROJECTS[projectName];
        if (!config) {
            fail(`Unknown project: ${projectName}. Available: ${Object.keys(PROJECTS).join(', ')}`);
        }

        console.log(`\nProcessing project: ${projectName}`);

        const languageEntries = await loadLanguageEntries(inputFolder, config.folder);

        // Filter entries
        for (const [lang, entries] of languageEntries) {
            const filtered = entries.filter(entry => config.shouldInclude(entry));
            languageEntries.set(lang, filtered);
        }

        // Create converter with English entries as reference
        const englishEntries = languageEntries.get('en') || [];
        const converter = new AppleStringsConverter(englishEntries);

        for (const [lang, entries] of languageEntries) {
            const { content, outputKeys } = converter.generate(lang, entries, config);

            // Write .strings file
            const outputPath = path.join(config.outputFolder, `${lang}.lproj`, `${config.tableName}.strings`);
            writeFile(outputPath, content);

            // Run postProcess hook
            if (config.postProcess) {
                config.postProcess(lang, outputKeys, config);
            }
        }
    }
}

processLocales(inputFolder, projectsToProcess).catch(err => fail(err.message));

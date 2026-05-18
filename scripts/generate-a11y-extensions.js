/**
 * Copyright 2026 Readium Foundation. All rights reserved.
 * Use of this source code is governed by the BSD-style license
 * available in the top-level LICENSE file of the project.
 *
 * This module generates Swift extensions for AccessibilityDisplayString
 * from localization keys.
 */

/**
 * Generates AccessibilityDisplayString Swift extension from localization keys.
 *
 * @param {string[]} keys - Array of localization keys (without prefix)
 * @param {string} outputPath - Path to write the generated Swift file
 * @param {string} keyPrefix - Prefix used in localization keys (e.g., "readium.a11y.")
 * @param {function} write - Write function (relativePath, content) => void
 */
function generateAccessibilityDisplayStringExtensions(keys, outputPath, keyPrefix, write) {
    const disclaimer = 'DO NOT EDIT. File generated automatically from https://github.com/edrlab/thorium-locales/.';

    // Filter out -descriptive keys (keep base keys only) and remove -compact suffix
    const filteredKeys = keys
        .filter(k => !k.endsWith('-descriptive'))
        .map(k => removeSuffix(k, '-compact'));

    // Remove duplicates (since we removed -compact suffix, some keys may now be the same)
    const uniqueKeys = [...new Set(filteredKeys)];

    let output = `// ${disclaimer}
public extension AccessibilityDisplayString {
`;

    for (const key of uniqueKeys) {
        const swiftName = convertKebabToCamelCase(key);
        output += `    static let ${swiftName}: Self = "${keyPrefix}${key}"\n`;
    }

    output += '}\n';

    write(outputPath, output);
}

/**
 * Converts a kebab-case string to camelCase.
 */
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
 * Removes a suffix from a string if present.
 */
function removeSuffix(str, suffix) {
    if (str.endsWith(suffix)) {
        return str.slice(0, -suffix.length);
    }
    return str;
}

module.exports = { generateAccessibilityDisplayStringExtensions };

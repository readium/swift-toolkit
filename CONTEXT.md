# Glossary

- **Caption**: the visible, authored caption of an image or graphic, i.e. the `<figcaption>` of its enclosing `<figure>`. Distinct from any accessibility text.
- **Accessible Name**: the short text identifying an element for assistive technologies, computed per [accname-1.2](https://www.w3.org/TR/accname-1.2) (aria-labelledby → aria-label → host-language sources such as `alt` → `title`). An empty `alt` marks a decorative image with no name.
- **Accessible Description**: supplementary text extending the accessible name, computed per [accname-1.2](https://www.w3.org/TR/accname-1.2) (aria-describedby → aria-description → unused `title`). Always a flat string.
- **Extended Description**: a structured, navigable long description of an image, associated via `aria-details` (per the DAISY extended-description best practices), living inline or in a separate resource with a backlink. NOT part of the accessible name/description computations and not implemented yet; when supported, it will be a separate attribute carrying a link/Locator, not a string.

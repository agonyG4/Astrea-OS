# Core Components

This directory is the public Astrea QML component module.

## Contract

Root-level QML files are the compatibility API used by apps through
`AstreaComponents`.

Most root files are small shims that forward to categorized implementations:

- `controls/`: buttons and segmented controls.
- `feedback/`: status, progress, and DNS cards.
- `form/`: settings rows, cards, search fields, and form controls.
- `menu/`: context menu primitives.
- `navigation/`: sidebars and nav items.
- `sidebar/`: sidebar-specific helpers.
- `theme/`: the shared Theme singleton implementation.
- `typography/`: text and divider primitives.

Keep the root shims until every consumer imports the categorized modules
directly. New shared components should use a category folder plus a root shim
when they are part of the public app API.

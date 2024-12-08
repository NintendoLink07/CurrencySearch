# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog],
and this project adheres to [Semantic Versioning].

## [1.0.1] - 2024-12-08

### Added

- Blizzard has limited the functionality of currency transfers when you have changed the currency list in any way (even when you haven't even touched anything and just refreshed the data).
A checkbox has been added that shows the current state of currency transfers:
If it's checked you can transfer currencies but you can't search for anything and the list is not ordered.
If it's unchecked currency transfers will produce a LUA error but you can search for currencies and the will be automatically ordered.



## [1.0.0] - 2024-11-17

### Added

- Initial release.

- Sorts currencies automatically by their ID instead of their name. This is togglable via the interface options.

- A search bar has been added to the currency frame so you can search for either the name or the description of currencies. (if you check the option in the interface options to include descriptions)

<!-- Links -->
[keep a changelog]: https://keepachangelog.com/en/1.0.0/
[semantic versioning]: https://semver.org/spec/v2.0.0.html

<!-- Versions -->
[unreleased]: https://github.com/NintendoLink07/RepSearch/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/NintendoLink07/RepSearch/releases/tag/1.0.1
[1.0.0]: https://github.com/NintendoLink07/RepSearch/releases/tag/1.0.0
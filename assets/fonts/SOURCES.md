# Bundled typefaces

The app bundles static font instances. No font is fetched at runtime.

| Flutter family | Original family and source | Weights | License |
| --- | --- | --- | --- |
| PlusInter | [Inter](https://github.com/google/fonts/tree/main/ofl/inter) | 400, 500, 600, 700, 800 | SIL OFL 1.1 |
| PlusDynaPuff | [DynaPuff](https://github.com/google/fonts/tree/main/ofl/dynapuff) | 400, 700 | SIL OFL 1.1 |
| PlusNunito | [Nunito](https://github.com/google/fonts/tree/main/ofl/nunito) | 400, 600, 800 | SIL OFL 1.1 |
| PlusRubikOne | [Rubik One](https://github.com/google/fonts/tree/main/ofl/rubikone) | 400 | SIL OFL 1.1 |
| PlusComfortaa | [Comfortaa](https://github.com/google/fonts/tree/main/ofl/comfortaa) | 400, 600, 700 | SIL OFL 1.1 |

Variable fonts were instantiated with fontTools 4.60.1 at the listed weight and default values of all other axes. Rubik One is the original static file. License and copyright files are in `assets/licenses/` and are included in the application assets. The `Plus…` names are Flutter family aliases. DynaPuff uses Rubik One for Cyrillic and Inter as the final fallback.

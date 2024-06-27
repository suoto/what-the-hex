# what-the-hex

This plugin inserts a virtual underscore character every 4 bytes to help
visualizing large hex numbers.

Before:

```
foo = 0xeeb9f157936810ab061456bf0000ec00cf1ffc1b88e53c3900a0730000000100000000e97500de75104742000000a7c1
bar = 0x0000e9294f6453c8
baz = 0x900001e7ccb1d4

fooA = 'heeb9f157936810ab061456bf0000ec00cf1ffc1b88e53c3900a0730000000100000000e97500de75104742000000a7c1
barA = 'h0000e9294f6453c8
bazA = 'h900001e7ccb1d4
```

After:

```
foo = 0xeeb9f157_936810ab_061456bf_0000ec00_cf1ffc1b_88e53c39_00a07300_00000100_000000e9_7500de75_10474200_0000a7c1
bar = 0x0000e929_4f6453c8
baz = 0x900001_e7ccb1d4

fooA = 'heeb9f157_936810ab_061456bf_0000ec00_cf1ffc1b_88e53c39_00a07300_00000100_000000e9_7500de75_10474200_0000a7c1
barA = 'h0000e929_4f6453c8
bazA = 'h900001_e7ccb1d4
```

Note that the underscore is virtual, so searching or copying text will ignore it
completely.

## Installation

Install with your preferred plugin manager. Note that what-the-hex requires
[plenary.nvim].

For example, using [vim-plug]:

```vimrc
Plug 'nvim-lua/plenary.nvim'
Plug 'suoto/what-the-hex'
```

## Options

### `vim.g.what_the_hex_separator`

Selects which character to insert.

Defaults to `_` (single underscore).

### `vim.g.what_the_hex_highlight`

Selects the highlight group of the inserted character.

Defaults to `Normal`.

### `vim.g.what_the_hex_group_width`

Selects how many characters each group has. Note that this is in nibbles, so `8`
corresponds to 4 bytes.

Defaults to `8`.

[plenary.nvim]: https://github.com/nvim-lua/plenary.nvim
[vim-plug]: https://github.com/junegunn/vim-plug

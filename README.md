# MicroKernel DOS Shell

A simple command line "DOS"-style shell for the Foenix F256 and Wildbits computers, which can be used to perform simple maintenance tasks. It also demonstrates how each of the MicroKernel calls are used.

## Drives

The system supports multiple drives:
- **Drive 0**: SD Card
- **Drive 1**: IEC Device #8 (e.g., 1541/1571/1581 or SD2IEC)
- **Drive 2**: IEC Device #9

Change drives by typing the drive number followed by a colon (e.g., `1:` to switch to IEC device 8).

## Commands

### File Operations

| Command | Description |
|---------|-------------|
| `ls` | Show directory listing |
| `dir` | Show directory listing (alias for ls) |
| `read <file>` | Print the contents of a file |
| `write <file>` | Write user input to a file |
| `dump <file>` | Hex-dump a file |
| `crc32 <file>` | Calculate CRC32 checksum of a file |
| `cp <src> <dst>` | Copy a file |
| `rename <old> <new>` | Rename a file |
| `rm <file>` | Delete a file |
| `del <file>` | Delete a file (alias for rm) |
| `delete <file>` | Delete a file (alias for rm) |
| `mkdir <dir>` | Create a directory |
| `rmdir <dir>` | Remove a directory |
| `mkfs <label>` | Create a new filesystem on the current drive |

### IEC Device Commands

The `@` command provides direct access to IEC devices (drives 1 and 2):

| Command | Description |
|---------|-------------|
| `@` | Read and display the IEC error/status channel |
| `@I` | Initialize (reset) the drive |
| `@V` | Validate (verify) the disk |
| `@N:name` | Format disk with the given name |
| `@S:file` | Scratch (delete) a file |
| `@R:new=old` | Rename a file |
| `@C:dst=src` | Copy a file within the drive |

You can also use `iecstat` and `ieccmd <cmd>` as alternatives to `@` and `@<cmd>`.

### System Commands

| Command | Description |
|---------|-------------|
| `lsf` | List programs resident in flash memory |
| `/<program>` | Run a program from flash by name |
| `help` | Display available commands |
| `about` | Display software and hardware information |
| `keys` | Keyboard status tracking demo |
| `wifi <ssid> <pass>` | Configure WiFi access point |

## Running Programs

Programs can be run by:
1. Typing the program name if it exists on the current drive
2. Prefixing with `/` to run from flash memory (e.g., `/monitor`)

## Building

Requires [64tass](https://sourceforge.net/projects/tass64/) assembler.

```bash
make
```

The output `dos_jr.bin` can be loaded and run on the F256.

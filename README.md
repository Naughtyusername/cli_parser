# cli_parser

A CLI argument parsing library for Odin. Built as a learning project to get better at programming and Odin idioms.

## Features

- **Flags**: Boolean switches (`--verbose`, `-v`)
- **Options**: Key-value pairs (`--output=file.txt`, `-o file.txt`)
- **Positionals**: Remaining arguments after flags/options
- **Validation**: Required options, type checking (string, int, f64, bool)
- **Error messages**: Helpful feedback on invalid input

## Usage

```odin
import "cli_parser"

main :: proc() {
    parser := make_parser("mytool", "A tool that does things")
    defer destroy_parser(&parser)

    // Register flags and options
    verbose := false
    output := ""
    threads := 4

    flag(&parser, &verbose, "verbose", "v", "Enable verbose output")
    option(&parser, &output, "output", "o", "Output file path", required = true)
    option(&parser, &threads, "threads", "t", "Number of threads")

    // Register positional arguments
    files := make([dynamic]string)
    defer delete(files)
    positionals(&parser, &files, "FILES", "Input files to process", required = true)

    // Parse
    ok, err := parse(&parser, os.args)
    if !ok {
        fmt.println("Error:", err)
        return
    }

    // Use the parsed values
    fmt.println("verbose:", verbose)
    fmt.println("output:", output)
    fmt.println("files:", files[:])
}
```

```bash
mytool --verbose -o out.txt file1.txt file2.txt
```

## Status

Core parsing and validation works. See `roadmap.org` for what's next.

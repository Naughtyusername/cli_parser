package cli_parser

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

// The types that Option can be
Option_Dest :: union {
	^string,
	^int,
	^f64,
	^bool,
}

// Flag switch like --verbose or -o
Flag :: struct {
	long:  string,
	short: string,
	help:  string,
	dest:  ^bool, // Pointer to where we'll store the result
}

// An option (key-value pair like --output=file.txt)
Option :: struct {
	long:     string, // Long name: "output"
	short:    string, // Short name: "o"
	help:     string, // Help text: "Output file path"
	required: bool, // Is this option required
	dest:     Option_Dest, // Pointer to where we store the value
}

// Positional arguments (leftover args like file1.txt file2.txt)
Positionals :: struct {
    name:        string,      // "FILES" (for help text display)
    help:        string,      // input files to process
    required:    bool,        // Must provide at least one
    dest:        ^[]string,   // where to store the collected file names
}

// Parser
Parser :: struct {
	name:        string, // Program name (for help text)
	description: string, // Progrm description
	flags:       [dynamic]Flag, // List of all registered flags
	options:     [dynamic]Option, // list of all registered options
    positionals: Maybe(Positionals), // not all programs need positionals, so maybe works well here
}

// API

// Create a new parser
make_parser :: proc(name: string, description: string) -> Parser {
    return Parser {
        name = name,
        description = description,
        flags = make([dynamic]Flag),
        positionals = nil,
    }
}

// Register a boolean flag
flag :: proc(parser: ^Parser, dest: ^bool, long: string, short: string, help: string) {
    append(&parser.flags, Flag{
        long = long,
        short = short,
        help = help,
        dest = dest,
    })
}

// Register an option (generic for any supported type)
option :: proc(parser: ^Parser, dest: ^$T, long: string, short: string, help: string, required := false) {
    opt := Option{
        long = long,
        short = short,
        help = help,
        required = required,
    }

    // Set the destination based on type
    when T == string {
        opt.dest = dest
    } else when T == int {
        opt.dest = dest
    } else when T == f64 {
        opt.dest = dest
    } else when T == bool {
        opt.dest = dest
    } else {
        #panic("Unsupported option type")
    }

    append(&parser.options, opt)
}

// Register positional arguments
positionals :: proc(parser: ^Parser, dest: ^[]string, name: string, help: string, required := false) {
    parser.positionals = Positionals {
        name = name,
        help = help,
        required = required,
        dest = dest,
    }
}

// Parse command-line arguments
parse :: proc(parser: ^Parser, args: []string) -> (ok: bool, error: string) {
    // Implementing soon.
    return true, ""
}

// Generate help text
print_help :: proc(parser: ^Parser) {
    // Implementing shortly
}

// Cleanup
destroy_parser :: proc(parser: ^Parser) {
    delete(parser.flags)
    delete(parser.options)
}


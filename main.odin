package cli_parser

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// ===================================================================================
// finally testing this!
// ===================================================================================

main :: proc() {
    parser := make_parser("testcli", "A test CLI tool")
    defer destroy_parser(&parser)

    verbose := false
    output := ""
    files := make([dynamic]string)

    flag(&parser, &verbose, "verbose", "v", "Enable verbose output")
    option(&parser, &output, "output", "o", "Output file", required = true)
    positionals(&parser, &files, "FILES", "Input files", required = true)

    ok, err := parse(&parser, os.args)
    if !ok {
        fmt.println("Error:", err)
        return
    }

    fmt.println("verbose:", verbose)
    fmt.println("output:", output)
    fmt.println("files:", files)
}

// ===================================================================================
// DATA STRUCTURES
// ===================================================================================
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
	name:     string, // "FILES" (for help text display)
	help:     string, // input files to process
	required: bool, // Must provide at least one
	dest:     ^[dynamic]string, // where to store the collected file names
}

// Parser
Parser :: struct {
	name:        string, // Program name (for help text)
	description: string, // Progrm description
	flags:       [dynamic]Flag, // List of all registered flags
	options:     [dynamic]Option, // list of all registered options
	positionals: Maybe(Positionals), // not all programs need positionals, so maybe works well here
}

// ===================================================================================
// API FUNCTIONS
// ===================================================================================
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
	append(&parser.flags, Flag{long = long, short = short, help = help, dest = dest})
}

// Register an option (generic for any supported type)
option :: proc(
	parser: ^Parser,
	dest: ^$T,
	long: string,
	short: string,
	help: string,
	required := false,
) {
	opt := Option {
		long     = long,
		short    = short,
		help     = help,
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
positionals :: proc(
	parser: ^Parser,
	dest: ^[dynamic]string,
	name: string,
	help: string,
	required := false,
) {
	parser.positionals = Positionals {
		name     = name,
		help     = help,
		required = required,
		dest     = dest,
	}
}

// ===================================================================================
// Main parse function
// ===================================================================================
// Parse command-line arguments
parse :: proc(parser: ^Parser, args: []string) -> (ok: bool, error: string) {
	// handle the empty args
	if len(args) == 0 {
		return true, ""
	}

	// track which required options we
	required_options_found := make(map[string]bool)
	defer delete(required_options_found)

	// loop through args, skips args[0] which is the program's name
	i := 1
	for i < len(args) {
		arg := args[i]

		if arg == "--help" {
			print_help(parser)
			return true, ""
			// help is special, we usually just want to see the help info and exit.
		}

		// ===================================================================================
		// check for short args (-s --something) short arg handling
		// ===================================================================================
		if strings.has_prefix(arg, "-") && !strings.has_prefix(arg, "--") && len(arg) > 1 {
			// short args
			short_name := string(arg[1:2]) // just the char after '-'

			// Try as option first
			opt := find_option_by_short(parser, short_name)
			if opt != nil {
				// check for duplicates
				if opt.long in required_options_found {
					return false, fmt.tprintf("Option -%s provided multiple times", opt.long)
				}

				// check that there is a second (next) argument
				if i + 1 >= len(args) {
					return false, fmt.tprintf("Option -%s requires a value", opt.long)
				}

				// make sure next arg isn't another flag
				next_arg := args[i + 1]
				if strings.has_prefix(next_arg, "-") {
					return false, fmt.tprintf(
						"Option -%s requires a value, got %s",
						short_name,
						next_arg,
					)
				}

				// Consume the value (move past it)
				i += 1
				value_str := args[i]

				// Validate and set
				if !set_option_value(opt, value_str) {
					return false, fmt.tprintf("Invalid value for -%s: %s", short_name, value_str)
				}

				// Track required
				if opt.required {
					// handling the verbose output and short by normalizing
					required_options_found[opt.long] = true
				}

			} else {
				// Try as flag
				flag := find_flag_by_short(parser, short_name)
				if flag != nil {
					flag.dest^ = true
				} else {
					return false, fmt.tprintf("Unknown flag: -%c", short_name)
				}
			}

			i += 1
			continue // next iteration - skip short arg handling
			// ===================================================================================
		}

		// ===================================================================================
		// Check for long arguments (--something) long arg handling
		// ===================================================================================
		if strings.has_prefix(arg, "--") {

			// Remove the "--" prefix to get the name
			name := arg[2:] // slice, taking out the first 2 index's? i believe

			// Check if it has an = sign (--output=value)
			if strings.contains(name, "=") {
				// Split into name and value
				parts := strings.split(name, "=")
				defer delete(parts) // strings.split allocates memory so delete it.
				opt_name := parts[0]

				// Find the option
				opt := find_option(parser, opt_name)
				if opt == nil {
					return false, fmt.tprintf("Unknown option: --%s", opt_name)
				}

				// Set its value
				value_str := parts[1]
				if !set_option_value(opt, value_str) {
					return false, fmt.tprintf("Invalid value for --%s: %s", opt_name, value_str)
				}

				// Track that we found a required option
				if opt.required {
					required_options_found[opt_name] = true
				}

			} else {
				// It's a flag (--verbose) or option without value yet (--output file.txt)
				// Check if it's an option first
				opt := find_option(parser, name)
				if opt != nil {
					// It's --option without =, so value is next arg

					// Check for duplicate
					if name in required_options_found {
						return false, fmt.tprintf("Option --%s provided multiple times", name)
					}

					// Check: is there a next arg?
					if i + 1 >= len(args) {
						return false, fmt.tprintf("Option --%s requires a value", name)
					}

					// Check: does next arg look like another flag?
					next_arg := args[i + 1]
					if strings.has_prefix(next_arg, "-") {
						return false, fmt.tprintf(
							"Option --%s requires a value, got %s",
							name,
							next_arg,
						)
					}

					// Consume the value
					i += 1
					value_str := args[i]

					// Set the value
					if !set_option_value(opt, value_str) {
						return false, fmt.tprintf("Invalid value for --%s: %s", name, value_str)
					}

					if opt.required {
						required_options_found[name] = true
					}
				} else {
					// Not an option, try as a flag
					flag := find_flag(parser, name)
					if flag != nil {
						flag.dest^ = true // set the flag to true
					} else {
						return false, fmt.tprintf("Unknown argument: --%s", name)
					}
				}
			}
		} else {
            if pos, ok := parser.positionals.?; ok {
                append(pos.dest, arg)
            }
		}

		i += 1
		continue // next iteration - skip long arg handling
		// ===================================================================================
	}

	// unwraps the Maybe, gives us the value and  a bool
	// Check all required options were provided
	for &opt in parser.options {
		if opt.required {
			if opt.long not_in required_options_found {
				return false, fmt.tprintf("Required argument %s not provided", opt.long)
			}
		}
	}
	// Validate required positionals (if registered and required)
	if pos, ok := parser.positionals.?; ok {
        if pos, ok := parser.positionals.?; ok {
            if pos.required && len(pos.dest^) == 0 {
                return false, fmt.tprintf("Required argument %s not provided", pos.name)
            }
        }
	}

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

// helper function to find matching flag names
find_flag :: proc(parser: ^Parser, name: string) -> ^Flag {
	for &flag in parser.flags {
		if flag.long == name {
			return &flag
		}
	}
	return nil
}

// Same but for short flags
find_flag_by_short :: proc(parser: ^Parser, name: string) -> ^Flag {
	for &flag in parser.flags {
		if flag.short == name {
			return &flag
		}
	}
	return nil
}


// helper funtion to find matching option names
find_option :: proc(parser: ^Parser, name: string) -> ^Option {
	for &option in parser.options {
		if option.long == name {
			return &option
		}
	}
	return nil
}

// helper function to find short names
find_option_by_short :: proc(parser: ^Parser, name: string) -> ^Option {
	for &option in parser.options {
		if option.short == name {
			return &option
		}
	}
	return nil
}

// Parse the string value and set it on the options dest.
set_option_value :: proc(option: ^Option, value_str: string) -> bool {
	// type switch on the union - figures out which type dest actually is
	switch dest in option.dest {
	case ^string:
		dest^ = value_str // For strings, just assign directly
		return true
	case ^int:
		// Parse string to int using strconv
		val, ok := strconv.parse_int(value_str)
		if !ok {
			return false // Failed to parse
		}
		dest^ = val // Dereference pointer and set value
		return true
	case ^f64:
		val, ok := strconv.parse_f64(value_str)
		if !ok {
			return false
		}
		dest^ = val
		return true
	case ^bool:
		// parse "true", "false", "1", "0", etc.
		dest^ = (value_str == "true" || value_str == "1")
		return true
	}
	return false
}

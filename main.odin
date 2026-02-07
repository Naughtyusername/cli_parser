package cli_parser

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// ===================================================================================
// finally testing this!
// ===================================================================================

// test command -> odin run . -- --verbose -o out.txt file1.txt file2.txt
main :: proc() {
	parser := make_parser("testcli", "A test CLI tool")
	defer destroy_parser(&parser)

	verbose := false
	output := ""
	files := make([dynamic]string)
    verbosity := 0

	flag(&parser, &verbose, "verbose", "v", "Enable verbose output")
	option(&parser, &output, "output", "o", "Output file", required = true)
	positionals(&parser, &files, "FILES", "  Input files", required = true)
    flag_count(&parser, &verbosity, "verbose", "v", "Verbosity level")

	ok, err, should_exit := parse(&parser, os.args)
	if should_exit {
		return
	}
    if !ok {
		fmt.println("Error:", err)
        return
    }

	fmt.println("verbose:", verbose)
	fmt.println("output:", output)
	fmt.println("files:", files)
	fmt.println("verbosity:", verbosity)
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
	name:           string, // Program name (for help text)
	description:    string, // Progrm description
	flags:          [dynamic]Flag, // List of all registered flags
	options:        [dynamic]Option, // list of all registered options
	positionals:    Maybe(Positionals), // not all programs need positionals, so maybe works well here

	// flag count for things like -vvv
	counting_flags: [dynamic]CountingFlag,
}

CountingFlag :: struct {
	long:  string,
	short: string,
	help:  string,
	dest:  ^int,
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
		counting_flags = make([dynamic]CountingFlag),
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
parse :: proc(parser: ^Parser, args: []string) -> (ok: bool, error: string, should_exit: bool) {
	// handle the empty args
	if len(args) == 0 {
		return true, "", false
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
			return true, "", true // ok, no eror, but should exit
			// help is special, we usually just want to see the help info and exit.
		}

        // Check if the arg is just -- e.g. mytool --output file.txt -- --weird-filename.txt
        if arg == "--" {
            // Everything after this is a positional
            i += 1
            for i < len(args) {
                if pos, ok := parser.positionals.?; ok {
                    append(pos.dest, args[i])
                }
                i += 1
            }
            break // exit the main loop
        }

		// ===================================================================================
		// check for short args (-s --something) short arg handling -- handle -vvv as well
		// ===================================================================================
		// Check for counting flags first (like -vvv)
		if strings.has_prefix(arg, "-") && !strings.has_prefix(arg, "--") && len(arg) > 1 {
			chars := arg[1:] // everythign after the dash: "vvv"
			first_char := rune(chars[0]) // 'v' (this is a byte/u8) (we do have to typecast it here too)

			// Check if all characters are the same
			all_same := true
			for c in chars {
				if c != first_char {
					all_same = false
					break
				}
			}

			if all_same {
				short_name := string(chars[0:1]) // convert first byte to string "v"
				cf := find_counting_flag_by_short(parser, short_name)
				if cf != nil {
					cf.dest^ += len(chars) // add the count (3 for -vvv)
					i += 1
					continue
				}
			}

			// short args
			short_name := string(arg[1:2]) // just the char after '-'

			// Try as option first
			opt := find_option_by_short(parser, short_name)
			if opt != nil {
				// check for duplicates
				if opt.long in required_options_found {
					return false, fmt.tprintf("Option --%s provided multiple times", opt.long), false
				}

				// check that there is a second (next) argument
				if i + 1 >= len(args) {
					return false, fmt.tprintf("Option -%s requires a value", opt.short), false
				}

				// make sure next arg isn't another flag
				next_arg := args[i + 1]
				if strings.has_prefix(next_arg, "-") {
					return false, fmt.tprintf(
						"Option -%s requires a value, got %s",
						short_name,
						next_arg,
					), false
				}

				// Consume the value (move past it)
				i += 1
				value_str := args[i]

				// Validate and set
				if !set_option_value(opt, value_str) {
					return false, fmt.tprintf("Invalid value for -%s: %s", short_name, value_str), false
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
					return false, fmt.tprintf("Unknown flag: -%s", short_name), false
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
					return false, fmt.tprintf("Unknown option: --%s", opt_name), false
				}

				// Set its value
				value_str := parts[1]
				if !set_option_value(opt, value_str) {
					return false, fmt.tprintf("Invalid value for --%s: %s", opt_name, value_str), false
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
						return false, fmt.tprintf("Option --%s provided multiple times", name), false
					}

					// Check: is there a next arg?
					if i + 1 >= len(args) {
						return false, fmt.tprintf("Option --%s requires a value", name), false
					}

					// Check: does next arg look like another flag?
					next_arg := args[i + 1]
					if strings.has_prefix(next_arg, "-") {
						return false, fmt.tprintf(
							"Option --%s requires a value, got %s",
							name,
							next_arg,
						), false
					}

					// Consume the value
					i += 1
					value_str := args[i]

					// Set the value
					if !set_option_value(opt, value_str) {
						return false, fmt.tprintf("Invalid value for --%s: %s", name, value_str), false
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
						return false, fmt.tprintf("Unknown flag: --%s", name), false
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
				return false, fmt.tprintf("Required option --%s not provided", opt.long), false
			}
		}
	}
	// Validate required positionals (if registered and required)
	if pos, ok := parser.positionals.?; ok {
		if pos.required && len(pos.dest^) == 0 {
			return false, fmt.tprintf("Required argument(s) <%s> not provided", pos.name), false
		}
	}

	return true, "", false
}

// Generate help text
print_help :: proc(parser: ^Parser) {
	fmt.println(parser.name, "-", parser.description)
	fmt.println()

	// Usage line
	fmt.printf("Usage: %s", parser.name)
	if len(parser.flags) > 0 || len(parser.options) > 0 {
		fmt.print("[OPTIONS]")
	}
	if pos, ok := parser.positionals.?; ok {
		fmt.printf(" %s", pos.name)
	}
	fmt.println() // end the usage line

	// Flags section
	if len(parser.flags) > 0 {
		fmt.println()
		fmt.println("Flags:")
		for flag in parser.flags {
			fmt.printf("  -%s, --%-12s %s\n", flag.short, flag.long, flag.help)
		}
	}

	// Options section
	if len(parser.options) > 0 {
		fmt.println()
		fmt.println("Options:")
		for opt in parser.options {
			required_str := opt.required ? " (required)" : ""
			fmt.printf("  -%s, --%-12s %s%s\n", opt.short, opt.long, opt.help, required_str)
		}
	}

	// Positionals section
	if pos, ok := parser.positionals.?; ok {
		fmt.println()
		fmt.println("Arguments:")
		required_str := pos.required ? " (required)" : ""
		fmt.printf("  %-16s %s%s\n", pos.name, pos.help, required_str)
	}
	fmt.println()
}

// Cleanup
destroy_parser :: proc(parser: ^Parser) {
	delete(parser.flags)
	delete(parser.options)
	delete(parser.counting_flags)
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

// Flag count registration function
flag_count :: proc(parser: ^Parser, dest: ^int, long: string, short: string, help: string) {
	append(
		&parser.counting_flags,
		CountingFlag{long = long, short = short, help = help, dest = dest},
	)
}

find_counting_flag_by_short :: proc(parser: ^Parser, name: string) -> ^CountingFlag {
	for &cf in parser.counting_flags {
		if cf.short == name {
			return &cf
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
